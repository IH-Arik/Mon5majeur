import re
from datetime import datetime, timedelta, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import NotFoundException
from app.modules.users.model import User
from app.modules.users.repository import UserRepository
from app.modules.users.schema import (
    CompleteProfileRequest,
    LanguageUpdateRequest,
    UserAdminUpdate,
    UserStatsResponse,
    UserUpdate,
)
from app.shared.pagination import Page, PaginationParams

# A validated lineup is a complete 5-player selection — mirrors
# analytics.service's definition so "active" means the same thing on both
# dashboards, not "opened the app".
_LINEUP_SIZE = 5
_VALIDATED_LINEUP_FILTER: dict = {
    f"selected_players.{_LINEUP_SIZE - 1}": {"$exists": True},
    f"selected_players.{_LINEUP_SIZE}": {"$exists": False},
}


class UserService:
    def __init__(self, repo: UserRepository) -> None:
        self.repo = repo

    async def get_user(self, user_id: PydanticObjectId) -> User:
        user = await self.repo.get(user_id)
        if not user:
            raise NotFoundException("User not found")
        return user

    async def list_users(self, params: PaginationParams, search: str | None = None) -> Page[User]:
        query_filter: dict = {}
        if search:
            pattern = re.compile(re.escape(search), re.IGNORECASE)
            query_filter = {
                "$or": [
                    {"email": pattern},
                    {"full_name": pattern},
                    {"team_name": pattern},
                ]
            }

        query = User.find(query_filter)
        total = await query.count()
        items = (
            await query.sort(-User.created_at)
            .skip(params.offset)
            .limit(params.limit)
            .to_list()
        )
        return Page.create(items, total, params)

    async def stats(self) -> UserStatsResponse:
        from app.modules.lineups.compat_model import FlutterPlayerSelection

        total = await User.find_all().count()
        banned = await User.find({"is_banned": True}).count()

        since = datetime.now(timezone.utc) - timedelta(days=30)
        new_signups = await User.find({"created_at": {"$gte": since}}).count()

        active_rows = await FlutterPlayerSelection.aggregate(
            [
                {"$match": {"submitted_at": {"$gte": since}, **_VALIDATED_LINEUP_FILTER}},
                {"$group": {"_id": "$user_id"}},
                {"$count": "n"},
            ]
        ).to_list()
        monthly_active = active_rows[0]["n"] if active_rows else 0

        return UserStatsResponse(
            total_users=total,
            new_signups_30d=new_signups,
            monthly_active_users=monthly_active,
            banned_users=banned,
        )

    async def update_profile(self, user: User, payload: UserUpdate) -> User:
        updates = payload.model_dump(exclude_unset=True, exclude_none=True)
        if not updates:
            return user
        return await self.repo.update(user, **updates)

    async def update_language(self, user: User, payload: LanguageUpdateRequest) -> User:
        return await self.repo.update(user, language=payload.language)

    async def complete_profile(self, user: User, payload: CompleteProfileRequest) -> User:
        return await self.repo.update(
            user,
            team_logo=payload.team_logo,
            team_name=payload.team_name,
            favourite_team=payload.favourite_team,
            date_of_birth=payload.date_of_birth,
            terms_accepted=payload.terms_accepted,
            push_notifications_enabled=payload.push_notifications_enabled,
            notification_types=payload.notification_types,
            is_profile_complete=True,
        )

    async def admin_update_user(self, user_id: PydanticObjectId, payload: UserAdminUpdate) -> User:
        user = await self.get_user(user_id)
        updates = payload.model_dump(exclude_unset=True, exclude_none=True)
        return await self.repo.update(user, **updates)

    async def delete_user(self, user_id: PydanticObjectId) -> None:
        """Erase the account and everything solely tied to it (spec §5.3 GDPR:
        "must erase ALL data ... not just deactivate"). Records shared with
        other users (e.g. a LeagueMatch's opponent side) are left intact —
        only this user's own documents are removed."""
        user = await self.get_user(user_id)

        from datetime import datetime, timezone

        from app.modules.analytics.model import AccountDeletionLog
        from app.modules.auth.model import OTPToken, RefreshToken
        from app.modules.bonuses.model import UserBonusInventory, UserBonusQuota
        from app.modules.competitions.model import CompetitionEntry
        from app.modules.fantasy_teams.model import FantasyTeam
        from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
        from app.modules.leagues.model import LeagueMembership
        from app.modules.leagues.reward_model import GlobalLeagueReward
        from app.modules.support.model import SupportTicket
        from app.modules.lineups.compat_model import FlutterPlayerSelection
        from app.modules.lineups.model import LineupSlot, LineupSubmission
        from app.modules.notifications.model import Notification
        from app.modules.tokens.model import TokenTransaction, TokenWallet

        # Audit the erasure BEFORE the data goes: afterwards there is nothing
        # left to count, and the retention dashboard would under-report churn
        # forever. Records no PII — only that a deletion happened, and
        # whether the account had ever actually played.
        had_played = await FlutterPlayerSelection.find(
            FlutterPlayerSelection.user_id == user_id
        ).count() > 0
        await AccountDeletionLog(
            deleted_at=datetime.now(timezone.utc),
            user_auto_id=user.auto_id,
            deletion_type="hard",
            had_validated_lineup=had_played,
        ).insert()

        await LineupSubmission.find(LineupSubmission.user_id == user_id).delete()
        await LineupSlot.find(LineupSlot.user_id == user_id).delete()
        await FlutterPlayerSelection.find(FlutterPlayerSelection.user_id == user_id).delete()
        await LeagueMembership.find(LeagueMembership.user_id == user_id).delete()
        await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.user_id == user_id).delete()
        await UserBonusQuota.find(UserBonusQuota.user_id == user_id).delete()
        await UserBonusInventory.find(UserBonusInventory.user_id == user_id).delete()
        await TokenTransaction.find(TokenTransaction.user_id == user_id).delete()
        await TokenWallet.find(TokenWallet.user_id == user_id).delete()
        await Notification.find(Notification.recipient_id == user_id).delete()
        await OTPToken.find(OTPToken.user_id == user_id).delete()
        await RefreshToken.find(RefreshToken.user_id == user_id).delete()
        # Support threads copy the email and pseudo at creation so they stay
        # readable — which makes them PII that has to go with the account.
        await SupportTicket.find(SupportTicket.user_id == user_id).delete()
        await GlobalLeagueReward.find(GlobalLeagueReward.user_id == user_id).delete()
        await CompetitionEntry.find(CompetitionEntry.user_id == user_id).delete()
        await FantasyTeam.find(FantasyTeam.owner_id == user_id).delete()

        await self.repo.delete(user)

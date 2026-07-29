from beanie import PydanticObjectId

from app.exceptions.errors import NotFoundException
from app.modules.users.model import User
from app.modules.users.repository import UserRepository
from app.modules.users.schema import (
    CompleteProfileRequest,
    LanguageUpdateRequest,
    UserAdminUpdate,
    UserUpdate,
)
from app.shared.pagination import Page, PaginationParams


class UserService:
    def __init__(self, repo: UserRepository) -> None:
        self.repo = repo

    async def get_user(self, user_id: PydanticObjectId) -> User:
        user = await self.repo.get(user_id)
        if not user:
            raise NotFoundException("User not found")
        return user

    async def list_users(self, params: PaginationParams) -> Page[User]:
        items, total = await self.repo.list(offset=params.offset, limit=params.limit)
        return Page.create(items, total, params)

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

        from app.modules.auth.model import OTPToken, RefreshToken
        from app.modules.bonuses.model import UserBonusInventory, UserBonusQuota
        from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
        from app.modules.leagues.model import LeagueMembership
        from app.modules.lineups.compat_model import FlutterPlayerSelection
        from app.modules.lineups.model import LineupSlot, LineupSubmission
        from app.modules.notifications.model import Notification
        from app.modules.tokens.model import TokenTransaction, TokenWallet

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

        await self.repo.delete(user)

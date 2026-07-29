from datetime import date

from beanie import PydanticObjectId

from app.modules.leagues.model import League, LeagueMembership, LeagueMatch
from app.shared.base_repository import BaseRepository


class LeagueRepository(BaseRepository[League]):
    def __init__(self) -> None:
        super().__init__(League)

    async def get_by_invite_code(self, code: str) -> League | None:
        return await League.find_one(League.invite_code == code.upper())

    async def get_global_league(self) -> League | None:
        return await League.find_one(League.type == "global")


class MembershipRepository(BaseRepository[LeagueMembership]):
    def __init__(self) -> None:
        super().__init__(LeagueMembership)

    async def get_membership(self, league_id: PydanticObjectId, user_id: PydanticObjectId) -> LeagueMembership | None:
        return await LeagueMembership.find_one(
            LeagueMembership.league_id == league_id,
            LeagueMembership.user_id == user_id,
        )

    async def get_user_memberships(self, user_id: PydanticObjectId) -> list[LeagueMembership]:
        return await LeagueMembership.find(LeagueMembership.user_id == user_id).to_list()

    async def get_league_members(self, league_id: PydanticObjectId) -> list[LeagueMembership]:
        return await LeagueMembership.find(
            LeagueMembership.league_id == league_id
        ).sort(LeagueMembership.rank).to_list()


class MatchRepository(BaseRepository[LeagueMatch]):
    def __init__(self) -> None:
        super().__init__(LeagueMatch)

    async def get_user_matches_today(self, user_id: PydanticObjectId, today: date) -> list[LeagueMatch]:
        return await LeagueMatch.find(
            LeagueMatch.nba_date == today,
            {
                "$or": [
                    {"home_user_id": user_id},
                    {"away_user_id": user_id},
                ]
            },
        ).to_list()

    async def get_league_matches(self, league_id: PydanticObjectId, match_day: int) -> list[LeagueMatch]:
        return await LeagueMatch.find(
            LeagueMatch.league_id == league_id,
            LeagueMatch.match_day == match_day,
        ).to_list()

    async def get_latest_completed_match(self, user_id: PydanticObjectId) -> LeagueMatch | None:
        """Most recent finished match for this user — Night's Results fallback
        when today's match is live but the user has no live-access, or there's
        no match today at all."""
        return await LeagueMatch.find(
            LeagueMatch.status == "completed",
            {
                "$or": [
                    {"home_user_id": user_id},
                    {"away_user_id": user_id},
                ]
            },
        ).sort(-LeagueMatch.nba_date).first_or_none()

from app.modules.home.schema import HomeDashboardResponse, HomeUserInfo
from app.modules.leagues.service import LeagueService
from app.modules.notifications.model import Notification
from app.modules.users.model import User


class HomeService:
    def __init__(self, league_service: LeagueService) -> None:
        self.league_service = league_service

    async def get_dashboard(self, user: User) -> HomeDashboardResponse:
        unread = await Notification.find(
            Notification.recipient_id == user.id,
            Notification.is_read == False,  # noqa: E712
        ).count()

        global_status = await self.league_service.get_global_league_status(user)
        all_matches = await self.league_service.get_my_matches_today(user)
        all_leagues = await self.league_service.get_my_leagues(user)

        return HomeDashboardResponse(
            user=HomeUserInfo(
                team_name=user.team_name,
                team_logo=user.team_logo,
                unread_notifications=unread,
            ),
            global_league=global_status,
            today_matches=all_matches[:1],     # preview: first match only
            my_leagues=all_leagues[:1],         # preview: first league only
            today_match_count=len(all_matches),
            my_league_count=len(all_leagues),
        )

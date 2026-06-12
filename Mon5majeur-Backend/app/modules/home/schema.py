from app.modules.leagues.schema import (
    GlobalLeagueStatusResponse,
    LeagueMatchResponse,
    MyLeagueResponse,
)
from app.shared.base_schema import BaseSchema


class HomeUserInfo(BaseSchema):
    team_name: str | None
    team_logo: str | None
    unread_notifications: int


class HomeDashboardResponse(BaseSchema):
    user: HomeUserInfo
    global_league: GlobalLeagueStatusResponse
    today_matches: list[LeagueMatchResponse]   # preview (first 1)
    my_leagues: list[MyLeagueResponse]          # preview (first 1)
    today_match_count: int
    my_league_count: int

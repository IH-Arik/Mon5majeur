from app.modules.home.service import HomeService
from app.modules.leagues.dependencies import get_league_service


def get_home_service() -> HomeService:
    return HomeService(league_service=get_league_service())

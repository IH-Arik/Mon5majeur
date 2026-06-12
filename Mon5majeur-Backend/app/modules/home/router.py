from fastapi import APIRouter, Depends

from app.modules.auth.dependencies import get_current_user
from app.modules.home.dependencies import get_home_service
from app.modules.home.schema import HomeDashboardResponse
from app.modules.home.service import HomeService
from app.modules.leagues.dependencies import get_league_service
from app.modules.leagues.schema import LeagueMatchResponse, MyLeagueResponse
from app.modules.leagues.service import LeagueService
from app.modules.users.model import User

router = APIRouter(prefix="/home", tags=["Home"])


@router.get(
    "",
    response_model=HomeDashboardResponse,
    summary="Home dashboard",
    description=(
        "Aggregated home screen data: user profile, global league status, "
        "today's matches preview (first 1), my leagues preview (first 1), "
        "and counts for the 'See all' buttons."
    ),
)
async def get_dashboard(
    current_user: User = Depends(get_current_user),
    service: HomeService = Depends(get_home_service),
) -> HomeDashboardResponse:
    return await service.get_dashboard(current_user)


@router.get(
    "/matches-today",
    response_model=list[LeagueMatchResponse],
    summary="My matches today (full list)",
    description="All duel matches scheduled for today's NBA date across every league the user is in.",
)
async def matches_today(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[LeagueMatchResponse]:
    return await service.get_my_matches_today(current_user)


@router.get(
    "/my-leagues",
    response_model=list[MyLeagueResponse],
    summary="My leagues (full list, from home)",
    description="Full league list — same as /leagues/my-leagues. Convenience alias from the home screen.",
)
async def my_leagues(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[MyLeagueResponse]:
    return await service.get_my_leagues(current_user)

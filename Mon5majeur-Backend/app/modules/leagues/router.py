from datetime import date

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query, status

from app.modules.auth.dependencies import get_current_superuser, get_current_user
from app.modules.leagues.dependencies import get_league_service
from app.modules.leagues.schema import (
    CreateLeagueRequest,
    GlobalLeagueStatusResponse,
    JoinLeagueRequest,
    JoinScreenResponse,
    LeagueDetailResponse,
    LeagueMatchResponse,
    LeagueResponse,
    MyLeagueResponse,
    PublicLeagueListItem,
)
from app.modules.leagues.service import LeagueService
from app.modules.users.model import User
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/leagues", tags=["Leagues"])


# ── Global League ─────────────────────────────────────────────────────────────

@router.get(
    "/global/status",
    response_model=GlobalLeagueStatusResponse,
    summary="Check if current user has joined the Global League",
)
async def global_league_status(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> GlobalLeagueStatusResponse:
    return await service.get_global_league_status(current_user)


@router.post(
    "/global/join",
    response_model=LeagueResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Join the NBA Global League",
)
async def join_global_league(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> LeagueResponse:
    return await service.join_global_league(current_user)


# ── My Leagues + Matches ──────────────────────────────────────────────────────

@router.get(
    "/my-leagues",
    response_model=list[MyLeagueResponse],
    summary="List all leagues the current user is in",
)
async def my_leagues(
    q: str | None = Query(default=None, description="Search leagues by name"),
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[MyLeagueResponse]:
    return await service.get_my_leagues(current_user, search=q)


@router.get(
    "/matches-today",
    response_model=list[LeagueMatchResponse],
    summary="Get all of today's duel matches for the current user",
)
async def my_matches_today(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[LeagueMatchResponse]:
    return await service.get_my_matches_today(current_user)


# ── Static list endpoints — MUST be before /{league_id} wildcard ─────────────

@router.get(
    "/join-screen",
    response_model=JoinScreenResponse,
    summary="Choose a league screen data",
    description="Returns public leagues preview (first 4) + total count.",
)
async def join_screen(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> JoinScreenResponse:
    return await service.get_join_screen()


@router.get(
    "/public",
    response_model=Page[PublicLeagueListItem],
    summary="Browse all open public leagues (paginated)",
)
async def list_public_leagues(
    params: PaginationParams = Depends(),
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> Page[PublicLeagueListItem]:
    items, total = await service.list_public_leagues(offset=params.offset, limit=params.limit)
    compact = [
        PublicLeagueListItem(
            id=i.id,
            name=i.name,
            current_size=i.current_size,
            max_size=i.max_size,
            budget=i.budget,
            status=i.status,
        )
        for i in items
    ]
    return Page.create(compact, total, params)


# ── Create / Join (Private & Public) ─────────────────────────────────────────

@router.post(
    "",
    response_model=LeagueResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new private or public league",
)
async def create_league(
    payload: CreateLeagueRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> LeagueResponse:
    return await service.create_league(current_user, payload)


@router.post(
    "/join",
    response_model=LeagueResponse,
    summary="Join a private league via invite code",
)
async def join_private_league(
    payload: JoinLeagueRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> LeagueResponse:
    return await service.join_by_invite_code(current_user, payload.code)


# ── Admin: daily close ────────────────────────────────────────────────────────

@router.post(
    "/admin/daily-close",
    summary="Run daily close: score matches → standings → advance (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def daily_close(
    nba_date: date = Query(..., description="NBA date to close (YYYY-MM-DD)"),
) -> dict:
    from app.modules.leagues.engine import run_daily_close
    return await run_daily_close(nba_date)


# ── League-specific endpoints — wildcard /{league_id} ─────────────────────────
# All static paths above MUST be declared before these.

@router.get(
    "/{league_id}",
    response_model=LeagueDetailResponse,
    summary="Get full league details (waiting room / lobby)",
)
async def get_league_detail(
    league_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> LeagueDetailResponse:
    return await service.get_league_detail(league_id, current_user)


@router.post(
    "/{league_id}/join",
    response_model=LeagueResponse,
    summary="Join an open public league by ID",
)
async def join_public_league(
    league_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> LeagueResponse:
    return await service.join_public_league(current_user, league_id)


@router.post(
    "/{league_id}/leave",
    summary="Leave a waiting league",
)
async def leave_league(
    league_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.leave_league(league_id, current_user)


@router.post(
    "/{league_id}/kick",
    summary="Kick a member from a waiting league (creator only)",
)
async def kick_member(
    league_id: PydanticObjectId,
    target_user_id: str = Query(..., description="User ID to kick"),
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.kick_member(league_id, PydanticObjectId(target_user_id), current_user)


@router.post(
    "/{league_id}/start",
    summary="Start the league (creator only — generates match schedule)",
)
async def start_league_by_creator(
    league_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.start_league_by_creator(league_id, current_user)


@router.delete(
    "/{league_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a league (creator only, waiting status)",
)
async def delete_league(
    league_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> None:
    await service.delete_league(league_id, current_user)

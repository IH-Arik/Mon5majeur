from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query, status

from app.modules.auth.dependencies import get_current_superuser, get_current_user
from app.modules.competitions.dependencies import get_competition_service
from app.modules.competitions.model import Competition, CompetitionEntry
from app.modules.competitions.schema import (
    CompetitionCreate,
    CompetitionEntryResponse,
    CompetitionResponse,
    CompetitionUpdate,
    EnterCompetitionRequest,
    LeaderboardEntry,
)
from app.modules.competitions.service import CompetitionService
from app.modules.users.model import User
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/competitions", tags=["Competitions"])


@router.get("", response_model=Page[CompetitionResponse], summary="List competitions")
async def list_competitions(
    status: str | None = Query(None, description="upcoming | open | live | completed"),
    params: PaginationParams = Depends(),
    service: CompetitionService = Depends(get_competition_service),
    _=Depends(get_current_user),
) -> Page[Competition]:
    return await service.list_competitions(status, params)


@router.get("/{competition_id}", response_model=CompetitionResponse, summary="Get competition details")
async def get_competition(
    competition_id: PydanticObjectId,
    service: CompetitionService = Depends(get_competition_service),
    _=Depends(get_current_user),
) -> Competition:
    return await service.get_competition(competition_id)


@router.post("/{competition_id}/enter", response_model=CompetitionEntryResponse, status_code=status.HTTP_201_CREATED, summary="Enter competition with my team")
async def enter_competition(
    competition_id: PydanticObjectId,
    payload: EnterCompetitionRequest,
    current_user: User = Depends(get_current_user),
    service: CompetitionService = Depends(get_competition_service),
) -> CompetitionEntry:
    return await service.enter_competition(competition_id, current_user, payload)


@router.get("/{competition_id}/leaderboard", response_model=list[LeaderboardEntry], summary="Get leaderboard")
async def get_leaderboard(
    competition_id: PydanticObjectId,
    offset: int = 0,
    limit: int = 50,
    service: CompetitionService = Depends(get_competition_service),
    _=Depends(get_current_user),
) -> list[LeaderboardEntry]:
    return await service.get_leaderboard(competition_id, offset, limit)


# ── Admin ─────────────────────────────────────────────────────────────────────

@router.post("", response_model=CompetitionResponse, status_code=status.HTTP_201_CREATED, summary="Create competition (admin)", dependencies=[Depends(get_current_superuser)])
async def create_competition(
    payload: CompetitionCreate,
    current_user: User = Depends(get_current_user),
    service: CompetitionService = Depends(get_competition_service),
) -> Competition:
    return await service.create_competition(payload, current_user)


@router.patch("/{competition_id}", response_model=CompetitionResponse, summary="Update competition (admin)", dependencies=[Depends(get_current_superuser)])
async def update_competition(
    competition_id: PydanticObjectId,
    payload: CompetitionUpdate,
    service: CompetitionService = Depends(get_competition_service),
) -> Competition:
    return await service.update_competition(competition_id, payload)

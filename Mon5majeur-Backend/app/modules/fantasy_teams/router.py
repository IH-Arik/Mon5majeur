from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_current_user
from app.modules.fantasy_teams.dependencies import get_fantasy_team_service
from app.modules.fantasy_teams.model import FantasyTeam
from app.modules.fantasy_teams.schema import (
    FantasyTeamCreate,
    FantasyTeamDetailResponse,
    FantasyTeamResponse,
    FantasyTeamUpdate,
)
from app.modules.fantasy_teams.service import FantasyTeamService
from app.modules.users.model import User
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/fantasy-teams", tags=["Fantasy Teams"])


@router.post("", response_model=FantasyTeamResponse, status_code=status.HTTP_201_CREATED, summary="Create my starting 5")
async def create_team(
    payload: FantasyTeamCreate,
    current_user: User = Depends(get_current_user),
    service: FantasyTeamService = Depends(get_fantasy_team_service),
) -> FantasyTeam:
    return await service.create_team(current_user, payload)


@router.get("", response_model=Page[FantasyTeamResponse], summary="List my teams")
async def list_my_teams(
    params: PaginationParams = Depends(),
    current_user: User = Depends(get_current_user),
    service: FantasyTeamService = Depends(get_fantasy_team_service),
) -> Page[FantasyTeam]:
    return await service.get_my_teams(current_user, params)


@router.get("/{team_id}", response_model=FantasyTeamDetailResponse, summary="Get team with player details")
async def get_team(
    team_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: FantasyTeamService = Depends(get_fantasy_team_service),
) -> FantasyTeamDetailResponse:
    return await service.get_team_with_players(team_id, current_user)


@router.patch("/{team_id}", response_model=FantasyTeamResponse, summary="Update my team")
async def update_team(
    team_id: PydanticObjectId,
    payload: FantasyTeamUpdate,
    current_user: User = Depends(get_current_user),
    service: FantasyTeamService = Depends(get_fantasy_team_service),
) -> FantasyTeam:
    return await service.update_team(team_id, current_user, payload)


@router.delete("/{team_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete my team")
async def delete_team(
    team_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: FantasyTeamService = Depends(get_fantasy_team_service),
) -> None:
    await service.delete_team(team_id, current_user)

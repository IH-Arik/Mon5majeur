from datetime import date

from beanie import PydanticObjectId
from fastapi import APIRouter, BackgroundTasks, Depends, Query

from app.modules.auth.dependencies import get_current_superuser, get_current_user
from app.modules.players.dependencies import get_player_service
from app.modules.players.model import Player
from app.modules.players.schema import (
    PlayerResponse,
    PlayerSearchParams,
    PlayerTodayItem,
)
from app.modules.players.service import PlayerService
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/players", tags=["Players"])


@router.get("", response_model=Page[PlayerResponse], summary="Search / list players")
async def list_players(
    q: str | None = Query(None, description="Search by name"),
    league: str | None = Query(None, description="nba | euroleague"),
    position: str | None = Query(None, description="PG | SG | SF | PF | C"),
    team_id: str | None = Query(None, description="Goalserve team ID"),
    pagination: PaginationParams = Depends(),
    service: PlayerService = Depends(get_player_service),
    _=Depends(get_current_user),
) -> Page[Player]:
    search = PlayerSearchParams(q=q, league=league, position=position, team_id=team_id)
    return await service.search_players(search, pagination)


@router.get("/today", response_model=list[PlayerTodayItem], summary="Players with games today")
async def players_today(
    nba_date: date | None = Query(None, description="Override date (YYYY-MM-DD), default=today UTC"),
    service: PlayerService = Depends(get_player_service),
    _=Depends(get_current_user),
) -> list[PlayerTodayItem]:
    return await service.get_players_today(nba_date)


@router.get("/{player_id}", response_model=PlayerResponse, summary="Get player details")
async def get_player(
    player_id: PydanticObjectId,
    service: PlayerService = Depends(get_player_service),
    _=Depends(get_current_user),
) -> Player:
    return await service.get_player(player_id)


# Admin endpoints -------------------------------------------------------

@router.post(
    "/sync",
    summary="Sync players roster from Goalserve (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def sync_players(
    background_tasks: BackgroundTasks,
    league: str = Query("nba", description="nba | euroleague"),
    service: PlayerService = Depends(get_player_service),
) -> dict:
    background_tasks.add_task(service.sync_from_goalserve, league)
    return {"detail": f"Player sync started for league={league}"}


@router.post(
    "/sync/schedule",
    summary="Sync today's NBA schedule from Goalserve (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def sync_schedule(
    background_tasks: BackgroundTasks,
    nba_date: date | None = Query(None, description="Override date, default=today UTC"),
    service: PlayerService = Depends(get_player_service),
) -> dict:
    background_tasks.add_task(service.sync_schedule, nba_date)
    return {"detail": "Schedule sync started"}


@router.post(
    "/sync/boxscore/{game_id}",
    summary="Sync box-score stats for a game (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def sync_boxscore(
    game_id: str,
    background_tasks: BackgroundTasks,
    service: PlayerService = Depends(get_player_service),
) -> dict:
    background_tasks.add_task(service.sync_game_stats, game_id)
    return {"detail": f"Boxscore sync started for game={game_id}"}


@router.post(
    "/sync/injuries",
    summary="Sync injury report from Goalserve (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def sync_injuries(
    background_tasks: BackgroundTasks,
    service: PlayerService = Depends(get_player_service),
) -> dict:
    background_tasks.add_task(service.sync_injury_report)
    return {"detail": "Injury sync started"}


@router.post(
    "/finalize-scores/{game_id}",
    summary="Compute fantasy scores for a finished game (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def finalize_scores(
    game_id: str,
    service: PlayerService = Depends(get_player_service),
) -> dict:
    count = await service.finalize_game_scores(game_id)
    return {"detail": f"Finalized {count} fantasy scores for game {game_id}"}


@router.post(
    "/recompute-prices",
    summary="Recompute all player prices (admin — runs automatically at 09:00 Paris)",
    dependencies=[Depends(get_current_superuser)],
)
async def recompute_prices(
    background_tasks: BackgroundTasks,
    service: PlayerService = Depends(get_player_service),
) -> dict:
    background_tasks.add_task(service.recompute_all_prices)
    return {"detail": "Price recomputation started"}


@router.post(
    "/seed",
    summary="Force full reseed: sync NBA roster + today's schedule (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def force_seed(
    background_tasks: BackgroundTasks,
    service: PlayerService = Depends(get_player_service),
) -> dict:
    async def _run():
        from app.core.logging import get_logger
        _log = get_logger(__name__)
        synced = await service.sync_from_goalserve("nba")
        scheduled = await service.sync_schedule(None)
        _log.info("Force seed done: %d players, %d games", synced, scheduled)
    background_tasks.add_task(_run)
    return {"detail": "Full NBA roster + schedule sync started in background"}

from datetime import date

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query

from app.exceptions.errors import BadRequestException
from app.modules.auth.dependencies import get_current_superuser, get_current_user
from app.modules.lineups.dependencies import get_lineup_service
from app.modules.lineups.schema import (
    LineupSubmissionResponse,
    MyLineupTodayResponse,
    SubmitLineupRequest,
)
from app.modules.lineups.service import LineupService
from app.modules.users.model import User

router = APIRouter(prefix="/lineups", tags=["Lineups"])


def _parse_league_id(league_id: str) -> PydanticObjectId:
    """A malformed league_id (not a 24-char hex ObjectId) used to reach
    PydanticObjectId() unguarded and blow up as an unhandled 500 - found
    while smoke-testing every endpoint. Bad input should be a clean 400,
    never a server error."""
    try:
        return PydanticObjectId(league_id)
    except Exception:
        raise BadRequestException(f"Invalid league_id: {league_id!r}")


@router.post("", response_model=LineupSubmissionResponse, summary="Submit or update lineup")
async def submit_lineup(
    payload: SubmitLineupRequest,
    user: User = Depends(get_current_user),
    service: LineupService = Depends(get_lineup_service),
) -> LineupSubmissionResponse:
    return await service.submit_lineup(user, payload)


@router.get(
    "/my",
    response_model=MyLineupTodayResponse,
    summary="Get my lineup for a league (today or specific date)",
)
async def my_lineup(
    league_id: str = Query(..., description="League MongoDB ObjectId"),
    nba_date: date | None = Query(None, description="Date (YYYY-MM-DD), default=today UTC"),
    user: User = Depends(get_current_user),
    service: LineupService = Depends(get_lineup_service),
) -> MyLineupTodayResponse:
    return await service.get_my_lineup(user, _parse_league_id(league_id), nba_date)


@router.get(
    "/bonus-status",
    summary="Get bonus availability for a league",
)
async def bonus_status(
    league_id: str = Query(..., description="League MongoDB ObjectId"),
    user: User = Depends(get_current_user),
    service: LineupService = Depends(get_lineup_service),
) -> dict:
    return await service.bonuses.get_status(user.id, _parse_league_id(league_id))


# Admin endpoints -------------------------------------------------------

@router.post(
    "/admin/lock",
    summary="Lock all lineups for a date (admin — runs at tip-off)",
    dependencies=[Depends(get_current_superuser)],
)
async def lock_lineups(
    nba_date: date = Query(...),
    service: LineupService = Depends(get_lineup_service),
) -> dict:
    count = await service.lock_lineups_for_date(nba_date)
    return {"detail": f"Locked {count} lineups for {nba_date}"}


@router.post(
    "/admin/fill-scores",
    summary="Fill slot scores from finalized PlayerGameStats (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def fill_scores(
    nba_date: date = Query(...),
    service: LineupService = Depends(get_lineup_service),
) -> dict:
    count = await service.fill_slot_scores_from_stats(nba_date)
    return {"detail": f"Filled {count} slot scores for {nba_date}"}


@router.post(
    "/admin/finalize-scores",
    summary="Finalize total lineup scores (apply Chef Curry bonus) (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def finalize_scores(
    nba_date: date = Query(...),
    service: LineupService = Depends(get_lineup_service),
) -> dict:
    count = await service.finalize_lineup_scores(nba_date)
    return {"detail": f"Finalized {count} lineup scores for {nba_date}"}

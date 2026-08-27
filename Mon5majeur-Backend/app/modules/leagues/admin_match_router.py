"""
Admin (dashboard) Match & Score Management.
Mounted at /api to match the dashboard's hardcoded base URL.

Two real problems this covers:
  1. A match whose night has passed but the 09:00 daily-close job never
     scored it (a lineup-scoring bug, a crashed job, etc.) — "stuck",
     genuinely awaiting resolution. Fixable by re-running the same scoring
     engine the cron uses, not by fabricating a status the game doesn't have.
  2. A completed match whose score needs a manual correction (a dispute) —
     fixable by overriding the score directly. Either action recomputes the
     league's standings afterward so wins/losses/points never drift out of
     sync with the corrected match.
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from app.exceptions.errors import BadRequestException, NotFoundException
from app.modules.auth.dependencies import get_current_superuser
from app.modules.leagues.constants import MATCH_STATUS_COMPLETED, MATCH_STATUS_UPCOMING
from app.modules.leagues.engine import score_match_day, update_standings
from app.modules.leagues.model import League, LeagueMatch
from app.modules.users.model import User

router = APIRouter(
    prefix="/admin/matches",
    tags=["Admin: Match & Score Management"],
    dependencies=[Depends(get_current_superuser)],
)


class MatchRow(BaseModel):
    id: str
    league_name: str
    home_team: str
    away_team: str
    nba_date: date
    status: str
    home_score: float | None
    away_score: float | None


class MatchPage(BaseModel):
    data: list[MatchRow]
    total: int
    page: int
    size: int


class ScoreOverrideRequest(BaseModel):
    home_score: float = Field(ge=0)
    away_score: float = Field(ge=0)


async def _to_row(match: LeagueMatch, league_by_id: dict, user_by_id: dict) -> MatchRow:
    league = league_by_id.get(match.league_id)
    home = user_by_id.get(match.home_user_id)
    away = user_by_id.get(match.away_user_id)
    return MatchRow(
        id=str(match.id),
        league_name=league.name if league else "Unknown league",
        home_team=(home.team_name or home.email) if home else "Unknown",
        away_team=(away.team_name or away.email) if away else "Unknown",
        nba_date=match.nba_date,
        status=match.status,
        home_score=match.home_score,
        away_score=match.away_score,
    )


async def _hydrate(matches: list[LeagueMatch]) -> tuple[dict, dict]:
    league_ids = {m.league_id for m in matches}
    user_ids = {m.home_user_id for m in matches} | {m.away_user_id for m in matches}
    leagues = await League.find({"_id": {"$in": list(league_ids)}}).to_list()
    users = await User.find({"_id": {"$in": list(user_ids)}}).to_list()
    return {lg.id: lg for lg in leagues}, {u.id: u for u in users}


@router.get(
    "/",
    response_model=MatchPage,
    summary="List matches — 'stuck' (past night, never scored) or 'completed' (for corrections)",
)
async def list_matches(
    status: str = Query("stuck", pattern="^(stuck|completed)$"),
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100),
) -> MatchPage:
    if status == "stuck":
        today = datetime.now(timezone.utc).date()
        query_filter = {"status": MATCH_STATUS_UPCOMING, "nba_date": {"$lt": today}}
        sort_field = "+nba_date"  # oldest stuck match first — longest overdue
    else:
        query_filter = {"status": MATCH_STATUS_COMPLETED}
        sort_field = "-nba_date"  # most recently played first

    query = LeagueMatch.find(query_filter)
    total = await query.count()

    sort_expr = LeagueMatch.nba_date if sort_field.startswith("+") else -LeagueMatch.nba_date
    matches = (
        await query.sort(sort_expr).skip((page - 1) * size).limit(size).to_list()
    )

    league_by_id, user_by_id = await _hydrate(matches)
    rows = [await _to_row(m, league_by_id, user_by_id) for m in matches]

    return MatchPage(data=rows, total=total, page=page, size=size)


@router.post(
    "/{match_id}/rescore/",
    response_model=MatchRow,
    summary="Re-run scoring for a stuck match using each side's actual saved lineup",
)
async def rescore_match(match_id: PydanticObjectId) -> MatchRow:
    match = await LeagueMatch.get(match_id)
    if not match:
        raise NotFoundException("Match not found")

    scored = await score_match_day(match.league_id, match.match_day, match.nba_date)
    if scored == 0:
        raise BadRequestException(
            "Scoring engine found nothing to score for this match day — "
            "check that the NBA games for this night are marked final."
        )
    await update_standings(match.league_id)

    match = await LeagueMatch.get(match_id)
    league_by_id, user_by_id = await _hydrate([match])
    return await _to_row(match, league_by_id, user_by_id)


@router.patch(
    "/{match_id}/score/",
    response_model=MatchRow,
    summary="Manually override a match's final score (dispute resolution)",
)
async def override_score(match_id: PydanticObjectId, payload: ScoreOverrideRequest) -> MatchRow:
    match = await LeagueMatch.get(match_id)
    if not match:
        raise NotFoundException("Match not found")

    match.home_score = payload.home_score
    match.away_score = payload.away_score
    # Tie → home wins (spec §4.6.2: "there are never draws") — same rule the
    # automatic scoring engine uses, so a manual override can't produce a
    # result the engine itself would never have produced.
    match.winner_id = (
        match.home_user_id if payload.home_score >= payload.away_score else match.away_user_id
    )
    match.status = MATCH_STATUS_COMPLETED
    await match.save()

    await update_standings(match.league_id)

    league_by_id, user_by_id = await _hydrate([match])
    return await _to_row(match, league_by_id, user_by_id)

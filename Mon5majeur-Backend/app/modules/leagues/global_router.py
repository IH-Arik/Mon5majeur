"""
Global League router.
Mounted at /api (no /v1 prefix).

  GET  /api/global-leagues/players-selection/  → fetch user's current selection
  POST /api/global-leagues/players-selection/  → save/update user's selection
"""
from datetime import datetime, timezone

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends

from app.exceptions.errors import ForbiddenException
from app.modules.auth.dependencies import get_current_user
from app.modules.leagues.constants import (
    GLOBAL_LEAGUE_BUDGET,
    LEAGUE_STATUS_WAITING,
    LEAGUE_TYPE_GLOBAL,
)
from app.modules.leagues.model import League
from app.modules.leagues.schema import GlobalLeagueSelectionResponse, PlayersSelectionRequest
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.compat_router import _nba_today
from app.modules.players.model import NBAGame, PlayerGameStats
from app.modules.users.model import User

router = APIRouter(prefix="/global-leagues", tags=["Global League (Flutter compat)"])

_MAX_BALANCE = 100.0


def _parse_price(raw) -> float:
    """'10.5M' → 10.5   or  10.5 → 10.5"""
    try:
        return float(str(raw).replace("M", "").strip())
    except (ValueError, TypeError):
        return 0.0


async def _get_global_league() -> League:
    """Prefer active (regular_season) global league; fall back to any global
    league; auto-create it if none exists yet (same lazy-create the old
    join_global_league() flow already relied on — GET/POST players-selection
    can be the very first Global League call a user makes, before ever
    hitting "join", so this endpoint can't just 404 on a missing league)."""
    from app.database.counters import next_seq

    league = await League.find_one(
        League.type == "global", League.status == "regular_season"
    )
    if not league:
        league = await League.find_one(League.type == "global")
    if league:
        return league

    league = await League(
        name="NBA Global League",
        type=LEAGUE_TYPE_GLOBAL,
        budget=GLOBAL_LEAGUE_BUDGET,
        max_size=999999,
        status=LEAGUE_STATUS_WAITING,
    ).insert()
    league.auto_id = await next_seq("leagues")
    await league.save()
    return league


async def _today_total_points(selected_players: list[dict]) -> int:
    """Sum today's fantasy score for each selected player from PlayerGameStats.
    Best-effort: players with no stat yet (game not started/no data) score 0."""
    if not selected_players:
        return 0

    today = await _nba_today()
    total = 0.0
    for p in selected_players:
        raw_id = p.get("id")
        if not raw_id:
            continue
        try:
            player_id = PydanticObjectId(str(raw_id))
        except Exception:
            continue
        stat = await PlayerGameStats.find_one(
            PlayerGameStats.player_id == player_id,
            PlayerGameStats.nba_date == today,
        )
        if stat and stat.fantasy_score:
            total += stat.fantasy_score
    return round(total)


async def _lock_info(user_id: PydanticObjectId, league: League) -> tuple[bool, int | None]:
    """(lineup_submitted, lock_in_seconds) for the Global League, same lock
    rule as private leagues: earliest tip-off on the current NBA date.
    lock_in_seconds contract: None = no game scheduled today, 0 = already
    locked, >0 = seconds until lock."""
    today = await _nba_today()

    submitted = await FlutterPlayerSelection.find_one({
        "user_id": user_id,
        "league_auto_id": league.auto_id,
        "match_day": league.current_match_day,
    }) is not None

    earliest_game = await NBAGame.find(
        NBAGame.nba_date == today,
        NBAGame.tip_off_time != None,  # noqa: E711
    ).sort(+NBAGame.tip_off_time).first_or_none()

    lock_in_seconds: int | None = None
    if earliest_game and earliest_game.tip_off_time:
        now_utc = datetime.now(timezone.utc)
        tip_off = earliest_game.tip_off_time
        if tip_off.tzinfo is None:
            tip_off = tip_off.replace(tzinfo=timezone.utc)
        remaining = (tip_off - now_utc).total_seconds()
        lock_in_seconds = max(0, int(remaining))

    return submitted, lock_in_seconds


async def _is_locked_today() -> bool:
    """True once the first game of the current NBA date has tipped off."""
    today = await _nba_today()
    earliest_game = await NBAGame.find(
        NBAGame.nba_date == today,
        NBAGame.tip_off_time != None,  # noqa: E711
    ).sort(+NBAGame.tip_off_time).first_or_none()

    if not earliest_game or not earliest_game.tip_off_time:
        return False

    now_utc = datetime.now(timezone.utc)
    tip_off = earliest_game.tip_off_time
    if tip_off.tzinfo is None:
        tip_off = tip_off.replace(tzinfo=timezone.utc)
    return now_utc >= tip_off


async def _build_response(
    league: League,
    selected_players: list[dict],
    user_id: PydanticObjectId,
) -> GlobalLeagueSelectionResponse:
    from app.modules.leagues.global_score_service import get_weekly_monthly_rank

    used = sum(_parse_price(p.get("price", 0)) for p in selected_players)
    remaining = max(0.0, _MAX_BALANCE - used)
    total_points = await _today_total_points(selected_players)
    submitted, lock_in_seconds = await _lock_info(user_id, league)
    today = await _nba_today()
    weekly_rank, monthly_rank = await get_weekly_monthly_rank(league, user_id, today)

    return GlobalLeagueSelectionResponse(
        match_day=league.current_match_day,
        selected_players=selected_players,
        total_points=total_points,
        max_balance=f"{int(_MAX_BALANCE)}M",
        current_balance=f"{remaining:.0f}M",
        lineup_submitted=submitted,
        lock_in_seconds=lock_in_seconds,
        weekly_rank=weekly_rank,
        monthly_rank=monthly_rank,
    )


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get(
    "/players-selection/",
    response_model=GlobalLeagueSelectionResponse,
    summary="Get user's global league player selection (Flutter: GlobalLeagueController.fetchSelection)",
)
async def get_global_selection(
    current_user: User = Depends(get_current_user),
) -> GlobalLeagueSelectionResponse:
    league = await _get_global_league()

    doc = await FlutterPlayerSelection.find_one({
        "user_id": current_user.id,
        "league_auto_id": league.auto_id,
        "match_day": league.current_match_day,
    })

    if not doc:
        return await _build_response(league, [], current_user.id)

    return await _build_response(league, doc.selected_players, current_user.id)


@router.post(
    "/players-selection/",
    response_model=GlobalLeagueSelectionResponse,
    summary="Save user's global league player selection (Flutter: GlobalLeagueController.saveSelection)",
)
async def post_global_selection(
    payload: PlayersSelectionRequest,
    current_user: User = Depends(get_current_user),
) -> GlobalLeagueSelectionResponse:
    league = await _get_global_league()

    if await _is_locked_today():
        raise ForbiddenException(
            "Night is locked — the first game has already tipped off"
        )

    doc = await FlutterPlayerSelection.find_one({
        "user_id": current_user.id,
        "league_auto_id": league.auto_id,
        "match_day": league.current_match_day,
    })

    if doc:
        doc.selected_players = payload.selected_players
        await doc.save()
    else:
        doc = FlutterPlayerSelection(
            user_id=current_user.id,
            league_id=league.id,
            league_auto_id=league.auto_id or 0,
            match_day=league.current_match_day,
            selected_players=payload.selected_players,
            submitted_at=datetime.now(timezone.utc),
        )
        await doc.insert()

    return await _build_response(league, doc.selected_players, current_user.id)

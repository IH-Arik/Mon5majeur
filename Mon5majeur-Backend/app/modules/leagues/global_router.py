"""
Global League router.
Mounted at /api (no /v1 prefix).

  GET  /api/global-leagues/players-selection/  → fetch user's current selection
  POST /api/global-leagues/players-selection/  → save/update user's selection
"""
from datetime import date, datetime, timezone

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends

from app.exceptions.errors import ForbiddenException, NotFoundException
from app.modules.auth.dependencies import get_current_user
from app.modules.leagues.constants import (
    GLOBAL_LEAGUE_BUDGET,
    LEAGUE_STATUS_WAITING,
    LEAGUE_TYPE_GLOBAL,
)
from app.modules.leagues.model import League, LeagueMembership
from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
from app.modules.leagues.schema import (
    GlobalLeagueSelectionResponse,
    MatchResultCompatResponse,
    PlayersSelectionRequest,
)
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


async def _global_matchday_date(league: League, match_day: int) -> tuple[date, bool]:
    """Return the NBA date represented by this Global League match day.

    The Global League does not create LeagueMatch rows, so we infer dates from
    the archived nightly score collection. The current active match day falls
    back to today's NBA date even before the archive job has run.
    """
    archived = await GlobalLeagueDailyScore.find(
        GlobalLeagueDailyScore.league_id == league.id,
    ).sort(+GlobalLeagueDailyScore.nba_date).to_list()
    archived_dates = list(dict.fromkeys(score.nba_date for score in archived))

    if match_day <= 0:
        raise NotFoundException("Invalid match day")

    today = await _nba_today()
    is_live_day = match_day == league.current_match_day

    if match_day <= len(archived_dates):
        return archived_dates[match_day - 1], is_live_day and archived_dates[match_day - 1] == today

    if is_live_day:
        return today, True

    raise NotFoundException("Match day is not available yet")


async def _global_status_for_date(nba_date: date, is_live_day: bool) -> str:
    games = await NBAGame.find(NBAGame.nba_date == nba_date).to_list()
    if not games:
        return "scheduled"

    statuses = {(g.status or "").lower() for g in games}
    if any(s in {"in play", "live"} for s in statuses):
        return "live"
    if all(s in {"final", "finished", "closed", "completed"} for s in statuses):
        return "completed"
    if is_live_day:
        return "scheduled"
    return "completed"


async def _global_total_for_user(
    league: League,
    user_id: PydanticObjectId,
    match_day: int,
    nba_date: date,
    use_archive: bool,
) -> float:
    if use_archive:
        archived = await GlobalLeagueDailyScore.find_one(
            GlobalLeagueDailyScore.user_id == user_id,
            GlobalLeagueDailyScore.league_id == league.id,
            GlobalLeagueDailyScore.nba_date == nba_date,
        )
        return round(archived.total_points, 2) if archived else 0.0

    sel = await FlutterPlayerSelection.find_one(
        FlutterPlayerSelection.user_id == user_id,
        FlutterPlayerSelection.league_auto_id == (league.auto_id or 0),
        FlutterPlayerSelection.match_day == match_day,
    )
    if not sel:
        return 0.0
    return await _today_total_points(sel.selected_players)


async def _global_selection_items(
    user_id: PydanticObjectId,
    league_auto_id: int,
    match_day: int,
    nba_date: date,
    include_selection: bool,
) -> list[dict]:
    if not include_selection:
        return []

    sel = await FlutterPlayerSelection.find_one(
        FlutterPlayerSelection.user_id == user_id,
        FlutterPlayerSelection.league_auto_id == league_auto_id,
        FlutterPlayerSelection.match_day == match_day,
    )
    if not sel:
        return []

    items: list[dict] = []
    for p in sel.selected_players:
        score = 0
        raw_id = p.get("id", "")
        try:
            player_oid = PydanticObjectId(raw_id)
            stats = await PlayerGameStats.find_one(
                PlayerGameStats.player_id == player_oid,
                PlayerGameStats.nba_date == nba_date,
                PlayerGameStats.score_computed == True,  # noqa: E712
            )
            if stats and stats.fantasy_score is not None:
                score = int(round(stats.fantasy_score))
        except Exception:
            pass
        items.append({
            "id": raw_id,
            "name": p.get("name", ""),
            "position": p.get("position", ""),
            "score": score,
        })
    return items


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

    # Global League runs on the no-bonus duel engine (spec/QA 08/08/2026,
    # item 4) — reject server-side even if a stale/modified client still
    # sends bonus flags, since the "+ Bonuses" button was only ever a
    # client-side mistake, not a real feature here.
    if payload.luxury_tax or payload.chef_curry or payload.sixth_man_player is not None:
        raise ForbiddenException("Bonuses are not available in the Global League")

    doc = await FlutterPlayerSelection.find_one({
        "user_id": current_user.id,
        "league_auto_id": league.auto_id,
        "match_day": league.current_match_day,
    })

    # The Global League has no LeagueMatch rows to read a night from, so the
    # night is the NBA date currently in play — the same one the lock
    # countdown above is computed against, keeping the two consistent.
    night = await _nba_today()

    if doc:
        doc.selected_players = payload.selected_players
        doc.nba_date = night
        await doc.save()
    else:
        doc = FlutterPlayerSelection(
            user_id=current_user.id,
            league_id=league.id,
            league_auto_id=league.auto_id or 0,
            match_day=league.current_match_day,
            selected_players=payload.selected_players,
            submitted_at=datetime.now(timezone.utc),
            nba_date=night,
        )
        await doc.insert()

    return await _build_response(league, doc.selected_players, current_user.id)


@router.get(
    "/matches/{match_day}/",
    response_model=MatchResultCompatResponse,
    summary="Global League night ranking/result (Flutter: Global Result tab)",
)
async def get_global_match_result(
    match_day: int,
    current_user: User = Depends(get_current_user),
) -> MatchResultCompatResponse:
    league = await _get_global_league()
    nba_date, is_live_day = await _global_matchday_date(league, match_day)
    use_archive = nba_date != await _nba_today() or not is_live_day
    status = await _global_status_for_date(nba_date, is_live_day)

    memberships = await LeagueMembership.find(
        LeagueMembership.league_id == league.id
    ).to_list()
    user_ids = [m.user_id for m in memberships]
    users = await User.find({"_id": {"$in": user_ids}}).to_list() if user_ids else []
    user_map = {u.id: u for u in users}

    player_scores: list[dict] = []
    for membership in memberships:
        user = user_map.get(membership.user_id)
        if not user:
            continue
        total = await _global_total_for_user(
            league,
            membership.user_id,
            match_day,
            nba_date,
            use_archive,
        )
        selection_items = await _global_selection_items(
            membership.user_id,
            league.auto_id or 0,
            match_day,
            nba_date,
            include_selection=is_live_day,
        )
        display_name = user.team_name or (user.email.split("@")[0] if user.email else "Unknown")
        player_scores.append({
            "player_id": user.auto_id or 0,
            "team_name": display_name,
            "username": user.full_name or display_name,
            "total_points": int(round(total)),
            "selection": selection_items,
        })

    player_scores.sort(key=lambda item: item["total_points"], reverse=True)

    return MatchResultCompatResponse(
        id=league.auto_id or 0,
        league_id=league.auto_id or 0,
        league_name=league.name,
        match_day=match_day,
        match_type="global_night",
        match_date=str(nba_date),
        status=status,
        player_scores=player_scores,
        pairs=[],
        created_at=datetime.now(timezone.utc).isoformat(),
    )

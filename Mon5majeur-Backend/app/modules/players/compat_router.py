"""
Flutter-compat player endpoints.
Mounted at /api (no /v1 prefix) to match Flutter's hardcoded URLs:

  GET /api/games-today/              → list of today's NBA games (Flutter Game.fromJson)
  GET /api/players-today/            → paginated players with daily_price (Flutter Player.fromJson)
  GET /api/players/{player_id}/info/ → player detail + season averages (Flutter PlayerInfoScreen)
"""
from datetime import date, datetime, timedelta, timezone

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.modules.auth.dependencies import get_current_user
from app.modules.leagues.schema import (
    GameCompatResponse,
    PlayerCompatItem,
    PlayerInfoResponse,
    PlayerSeasonAverages,
    PlayerTodayScoreItem,
    PlayersTodayPageResponse,
    PlayersTodayScoresResponse,
)
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.users.model import User

router = APIRouter(tags=["Players & Games (Flutter compat)"])

_PAGE_SIZE = 100


async def _nba_today() -> date:
    """
    Return the NBA 'game date' that has active games.
    NBA uses ET dates — Paris morning (01:00-09:00) is still the previous ET day.
    We check today UTC and yesterday UTC; whichever has games in the DB wins.
    Falls back to today UTC if neither has games yet.
    """
    utc_today = datetime.now(timezone.utc).date()
    for candidate in (utc_today, utc_today - timedelta(days=1)):
        count = await NBAGame.find(NBAGame.nba_date == candidate).count()
        if count > 0:
            return candidate
    return utc_today


# ── Status mapping ────────────────────────────────────────────────────────────

_STATUS_MAP = {
    "scheduled": "Not Started",
    "live": "Live",
    "final": "Final",
}


def _game_to_compat(game: NBAGame) -> GameCompatResponse:
    try:
        game_int_id = int(game.goalserve_id)
    except (ValueError, TypeError):
        game_int_id = 0

    game_time = ""
    datetime_utc = ""
    if game.tip_off_time:
        t = game.tip_off_time
        hour = t.hour % 12 or 12
        ampm = "AM" if t.hour < 12 else "PM"
        game_time = f"{hour}:{t.minute:02d} {ampm} UTC"
        datetime_utc = t.isoformat()

    return GameCompatResponse(
        id=game_int_id,
        home_team=game.home_team_name,
        home_team_id=game.home_team_id,
        away_team=game.away_team_name,
        away_team_id=game.away_team_id,
        game_time=game_time,
        status=_STATUS_MAP.get(game.status, game.status),
        venue="",
        timezone="UTC",
        datetime_utc=datetime_utc,
        home_score=game.home_score,
        away_score=game.away_score,
    )


def _player_to_compat(player: Player) -> PlayerCompatItem:
    status = "OUT" if player.is_out else "OK"
    price_str = f"{player.daily_price:.1f}M"
    return PlayerCompatItem(
        id=str(player.id),
        name=player.full_name,
        position=player.position or "",
        team=player.team_name or "",
        team_id=player.team_goalserve_id or None,
        status=status,
        price=price_str,
        avg=round(player.avg_fantasy_score),
    )


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get(
    "/games-today/",
    response_model=list[GameCompatResponse],
    summary="Today's NBA games (Flutter: _fetchTodaysGames)",
)
async def games_today(
    nba_date: str | None = Query(None, description="Override date YYYY-MM-DD, default=NBA current date"),
    _: User = Depends(get_current_user),
) -> list[GameCompatResponse]:
    if nba_date:
        try:
            today = date.fromisoformat(nba_date)
        except ValueError:
            today = await _nba_today()
    else:
        today = await _nba_today()

    games = await NBAGame.find(NBAGame.nba_date == today).sort(+NBAGame.tip_off_time).to_list()
    return [_game_to_compat(g) for g in games]


@router.get(
    "/players-today/",
    response_model=PlayersTodayPageResponse,
    summary="Paginated players with games today (Flutter: _fetchPlayers / _loadAllRemainingPages)",
)
async def players_today(
    request: Request,
    page: int = Query(1, ge=1, description="Page number (1-based)"),
    _: User = Depends(get_current_user),
) -> PlayersTodayPageResponse:
    today = await _nba_today()

    games = await NBAGame.find(NBAGame.nba_date == today).to_list()
    team_ids_playing: set[str] = set()
    for g in games:
        team_ids_playing.add(g.home_team_id)
        team_ids_playing.add(g.away_team_id)

    if not team_ids_playing:
        return PlayersTodayPageResponse(count=0, next=None, results=[])

    total = await Player.find(
        {"team_goalserve_id": {"$in": list(team_ids_playing)}, "is_active": True}
    ).count()

    offset = (page - 1) * _PAGE_SIZE
    players = await Player.find(
        {"team_goalserve_id": {"$in": list(team_ids_playing)}, "is_active": True}
    ).sort(-Player.daily_price).skip(offset).limit(_PAGE_SIZE).to_list()

    has_next = offset + len(players) < total
    next_url: str | None = None
    if has_next:
        base = str(request.base_url).rstrip("/")
        next_url = f"{base}/api/players-today/?page={page + 1}"

    return PlayersTodayPageResponse(
        count=total,
        next=next_url,
        results=[_player_to_compat(p) for p in players],
    )


@router.get(
    "/games-history/",
    response_model=list[GameCompatResponse],
    summary="Last 7 days of NBA games (Flutter: Results / Score history screen)",
)
async def games_history(
    days: int = Query(7, ge=1, le=30, description="How many days back to fetch"),
    _: User = Depends(get_current_user),
) -> list[GameCompatResponse]:
    nba_today = await _nba_today()
    since = nba_today - timedelta(days=days - 1)
    games = await NBAGame.find(
        NBAGame.nba_date >= since,
        NBAGame.nba_date <= nba_today,
    ).sort(-NBAGame.nba_date).to_list()
    return [_game_to_compat(g) for g in games]


@router.get(
    "/players-today-scores/",
    response_model=PlayersTodayScoresResponse,
    summary="Today's fantasy player scores sorted by score desc (Flutter: MyMatchScreen > Todays Fantasy Players Score)",
)
async def players_today_scores(
    _: User = Depends(get_current_user),
) -> PlayersTodayScoresResponse:
    today = await _nba_today()

    stats = await PlayerGameStats.find(
        PlayerGameStats.nba_date == today,
        PlayerGameStats.did_not_play == False,
        PlayerGameStats.score_computed == True,
    ).sort(-PlayerGameStats.fantasy_score).to_list()

    if not stats:
        return PlayersTodayScoresResponse(results=[])

    player_ids = list({s.player_id for s in stats})
    players_list = await Player.find({"_id": {"$in": player_ids}}).to_list()
    player_map = {p.id: p for p in players_list}

    items: list[PlayerTodayScoreItem] = []
    for s in stats:
        p = player_map.get(s.player_id)
        if not p:
            continue
        items.append(PlayerTodayScoreItem(
            id=str(p.id),
            name=p.full_name,
            position=p.position or "",
            team=p.team_name or "",
            score=round(s.fantasy_score or 0),
        ))

    return PlayersTodayScoresResponse(results=items)


@router.get(
    "/players/{player_id}/info/",
    response_model=PlayerInfoResponse,
    summary="Player detail + season averages (Flutter: PlayerInfoScreen)",
)
async def player_info(
    player_id: str,
    _: User = Depends(get_current_user),
) -> PlayerInfoResponse:
    try:
        oid = PydanticObjectId(player_id)
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid player_id format")

    player = await Player.get(oid)
    if not player:
        raise HTTPException(status_code=404, detail="Player not found")

    # ── Season averages: last 10 non-DNP games ─────────────────────────────
    recent_stats = await PlayerGameStats.find(
        PlayerGameStats.player_id == player.id,
        PlayerGameStats.did_not_play == False,
        PlayerGameStats.score_computed == True,
    ).sort(-PlayerGameStats.nba_date).limit(10).to_list()

    def _avg(values: list[float | int]) -> float:
        return round(sum(values) / len(values), 1) if values else 0.0

    averages = PlayerSeasonAverages(
        points=_avg([s.points for s in recent_stats]),
        rebounds=_avg([s.rebounds for s in recent_stats]),
        assists=_avg([s.assists for s in recent_stats]),
        steals=_avg([s.steals for s in recent_stats]),
        turnovers=_avg([s.turnovers for s in recent_stats]),
        fantasy=_avg([s.fantasy_score or 0.0 for s in recent_stats]),
    )

    # ── Rating: avg_fantasy / 6, clamped [0, 10] ───────────────────────────
    raw_rating = (player.avg_fantasy_score / 6) if player.avg_fantasy_score else 0.0
    rating = round(min(max(raw_rating, 0.0), 10.0), 1)

    # ── Selected Today % ───────────────────────────────────────────────────
    today = await _nba_today()
    player_id_str = str(player.id)

    total_today = await FlutterPlayerSelection.find(
        {"submitted_at": {"$gte": datetime.combine(today, datetime.min.time()).replace(tzinfo=timezone.utc)}}
    ).count()

    selected_count = await FlutterPlayerSelection.find(
        {
            "submitted_at": {"$gte": datetime.combine(today, datetime.min.time()).replace(tzinfo=timezone.utc)},
            "selected_players.id": player_id_str,
        }
    ).count()

    selected_pct = round((selected_count / total_today) * 100) if total_today > 0 else 0

    return PlayerInfoResponse(
        id=player_id_str,
        name=player.full_name,
        position=player.position or "",
        team=player.team_name or "",
        team_id=player.team_goalserve_id,
        status="Out" if player.is_out else "Active",
        current_value=f"{player.daily_price:.0f}M",
        rating=rating,
        season_averages=averages,
        selected_today_pct=selected_pct,
    )

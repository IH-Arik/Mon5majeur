"""
Real Goalserve basketball client — the subscription is active (verified
manually against the live API), unlike the "temporary" NBA CDN workaround in
nba_cdn.py which is (a) unreliable — cdn.nba.com's Akamai edge blocks most
requests with an intermittent, non-deterministic 403 — and (b) uses NBA.com's
own player/team ID scheme, which does not match Goalserve's.

Feeds used (confirmed working against the live account):
  Schedule (all dates, incl. upcoming) : bsktbl/nba-shedule   [sic — Goalserve's
                                          own spelling, not a typo on our side]
  Scores + full box score, per date    : bsktbl/nba-scores?date=DD.MM.YYYY

No roster/squad feed could be found for this account (every guessed feed name
either 500'd or, for a GUID-based /bsktbl/{category}/squad/{guid} path, wants
an identifier we have no way to obtain). Player and team identity are instead
resolved incrementally from box-score data — see service.py::sync_scores_for_date.
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import date, datetime, timedelta, timezone

import httpx

from app.core.config import settings

logger = __import__("logging").getLogger(__name__)

_BASE = "https://www.goalserve.com/getfeed"

# Goalserve's status strings map onto our 3-state vocabulary. Anything not
# recognized falls through to "live" — deliberately, since the unrecognized
# case in practice is always some in-progress clock state ("1st Quarter",
# "Halftime", "OT", etc.), never a pre-game or truly-finished state.
_FINAL_STATUSES = {"final", "final ot", "finished", "ft"}
_SCHEDULED_STATUSES = {"not started", "postponed", "scheduled"}


def _status_of(raw: str) -> str:
    s = (raw or "").strip().lower()
    if s in _FINAL_STATUSES:
        return "final"
    if s in _SCHEDULED_STATUSES:
        return "scheduled"
    return "live"


def _feed_url(path: str) -> str:
    return f"{_BASE}/{settings.GOALSERVE_API_KEY}/{path}"


async def _get_xml(path: str) -> ET.Element | None:
    async with httpx.AsyncClient(timeout=25) as client:
        resp = await client.get(_feed_url(path))
        resp.raise_for_status()
        if not resp.content:
            return None
        return ET.fromstring(resp.content)


def _parse_goalserve_date(date_str: str) -> date | None:
    """'13.06.2026' -> date(2026, 6, 13)."""
    if not date_str:
        return None
    try:
        return datetime.strptime(date_str, "%d.%m.%Y").date()
    except ValueError:
        return None


def _parse_tip_off(match_el: ET.Element, game_date: date | None) -> datetime | None:
    """Goalserve gives local time ('7:30 PM') + a timezone name ('EST') per
    match, not a ready UTC timestamp. EST/EDT covers all NBA game cities
    closely enough for lock-timer purposes (a few minutes off at most for
    non-Eastern arenas — the same tolerance the rest of this app already
    accepts elsewhere for tip-off estimates)."""
    time_str = match_el.get("time", "")
    if not time_str or not game_date:
        return None
    try:
        naive = datetime.strptime(time_str, "%I:%M %p")
    except ValueError:
        return None
    combined = datetime.combine(game_date, naive.time())
    # EST = UTC-5 (ignoring DST, same simplification as above)
    return combined.replace(tzinfo=timezone(timedelta(hours=-5))).astimezone(timezone.utc)


def _team_dict(team_el: ET.Element | None) -> dict:
    if team_el is None:
        return {"id": "", "name": "", "score": None}
    total = team_el.get("totalscore", "")
    return {
        "id": team_el.get("id", ""),
        "name": team_el.get("name", ""),
        "score": int(total) if total.isdigit() else None,
    }


# ---------------------------------------------------------------------------
# Schedule (any date, including future — Goalserve's nba-scores feed only
# returns dates that have already started, so upcoming games need this feed)
# ---------------------------------------------------------------------------

_schedule_cache: tuple[datetime, ET.Element] | None = None
_SCHEDULE_CACHE_TTL = timedelta(hours=6)


async def _get_schedule_root() -> ET.Element | None:
    """The full-season schedule is a ~750KB blob — cache it in-process for a
    few hours rather than re-downloading on every call (sync_today_schedule_job
    runs once a day, but start_league can call this repeatedly)."""
    global _schedule_cache
    now = datetime.now(timezone.utc)
    if _schedule_cache and (now - _schedule_cache[0]) < _SCHEDULE_CACHE_TTL:
        return _schedule_cache[1]

    root = await _get_xml("bsktbl/nba-shedule")
    if root is not None:
        _schedule_cache = (now, root)
    return root


async def fetch_schedule_for_date(nba_date: date) -> list[dict]:
    """Games scheduled for `nba_date` (any date — past, today, or future).
    No scores/box-score here; use fetch_scores_for_date once the date has
    actually started."""
    root = await _get_schedule_root()
    if root is None:
        return []

    games = []
    for match_el in root.iter("match"):
        game_date = _parse_goalserve_date(match_el.get("formatted_date", ""))
        if game_date != nba_date:
            continue

        home = _team_dict(match_el.find("hometeam"))
        away = _team_dict(match_el.find("awayteam"))
        games.append({
            "goalserve_game_id": match_el.get("id", ""),
            "nba_date": game_date,
            "home_team_id": home["id"],
            "away_team_id": away["id"],
            "home_team_name": home["name"],
            "away_team_name": away["name"],
            "status": _status_of(match_el.get("status", "")),
            "tip_off_utc": _parse_tip_off(match_el, game_date),
            "home_score": home["score"],
            "away_score": away["score"],
        })
    return games


# ---------------------------------------------------------------------------
# Scores + box score for a specific date (today or a past date)
# ---------------------------------------------------------------------------

_STAT_ATTR_MAP = {
    "points": "points",
    "total_rebounds": "rebounds",
    "assists": "assists",
    "steals": "steals",
    "blocks": "blocks",
    "turnovers": "turnovers",
    "field_goals_made": "field_goals_made",
    "field_goals_attempts": "field_goals_attempted",
    "threepoint_goals_made": "threepoint_made",
    "threepoint_goals_attempts": "threepoint_attempted",
    "freethrows_goals_made": "freethrow_made",
    "freethrows_goals_attempts": "freethrow_attempted",
}


def _parse_player(player_el: ET.Element, team_id: str) -> dict:
    def _int(attr: str) -> int:
        raw = player_el.get(attr, "0")
        try:
            return int(raw)
        except ValueError:
            return 0

    minutes_raw = player_el.get("minutes", "0")
    try:
        minutes = int(minutes_raw)
    except ValueError:
        minutes = 0

    stats = {our_field: _int(gs_attr) for gs_attr, our_field in _STAT_ATTR_MAP.items()}
    return {
        "goalserve_player_id": player_el.get("id", ""),
        "full_name": player_el.get("odd_name") or player_el.get("name", ""),
        "position": player_el.get("pos", ""),
        "team_goalserve_id": team_id,
        "minutes_played": minutes,
        "did_not_play": minutes == 0,
        **stats,
    }


async def fetch_scores_for_date(nba_date: date) -> list[dict]:
    """Games + full box score for `nba_date`. Empty for dates with no game
    that has started yet — use fetch_schedule_for_date for pre-game info."""
    date_str = nba_date.strftime("%d.%m.%Y")
    root = await _get_xml(f"bsktbl/nba-scores?date={date_str}")
    if root is None:
        return []

    games = []
    for match_el in root.iter("match"):
        game_date = _parse_goalserve_date(match_el.get("formatted_date", "")) or nba_date
        home = _team_dict(match_el.find("hometeam"))
        away = _team_dict(match_el.find("awayteam"))

        players: list[dict] = []
        player_stats_el = match_el.find("player_stats")
        if player_stats_el is not None:
            for side, team_id in (("hometeam", home["id"]), ("awayteam", away["id"])):
                side_el = player_stats_el.find(side)
                if side_el is None:
                    continue
                for group in ("starters", "bench"):
                    group_el = side_el.find(group)
                    if group_el is None:
                        continue
                    for player_el in group_el.findall("player"):
                        players.append(_parse_player(player_el, team_id))

        games.append({
            "goalserve_game_id": match_el.get("id", ""),
            "nba_date": game_date,
            "home_team_id": home["id"],
            "away_team_id": away["id"],
            "home_team_name": home["name"],
            "away_team_name": away["name"],
            "status": _status_of(match_el.get("status", "")),
            "tip_off_utc": _parse_tip_off(match_el, game_date),
            "home_score": home["score"],
            "away_score": away["score"],
            "players": players,
        })
    return games

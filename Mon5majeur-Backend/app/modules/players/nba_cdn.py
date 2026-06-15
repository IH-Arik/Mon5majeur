"""
NBA CDN data client — replaces Goalserve (temporary, free, no API key required).
Switch back to Goalserve once basketball subscription is active.

Endpoints:
  Today's scoreboard : https://cdn.nba.com/static/json/liveData/scoreboard/todaysScoreboard_00.json
  Boxscore           : https://cdn.nba.com/static/json/liveData/boxscore/boxscore_{gameId}.json
  Player index       : https://cdn.nba.com/static/json/staticData/playerIndex.json
  Full schedule      : https://cdn.nba.com/static/json/staticData/scheduleLeagueV2_1.json
"""
from __future__ import annotations

import logging
import re
from datetime import date, datetime, timezone

import httpx

logger = logging.getLogger(__name__)

_CDN = "https://cdn.nba.com/static/json"
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Referer": "https://www.nba.com/",
    "Accept": "application/json",
}

# gameStatus codes
STATUS_SCHEDULED = 1
STATUS_LIVE = 2
STATUS_FINAL = 3

STATUS_MAP = {
    STATUS_SCHEDULED: "scheduled",
    STATUS_LIVE: "live",
    STATUS_FINAL: "final",
}


async def _get(url: str) -> dict:
    async with httpx.AsyncClient(timeout=20, headers=_HEADERS) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        return resp.json()


# ---------------------------------------------------------------------------
# Today's scoreboard
# ---------------------------------------------------------------------------

async def fetch_today_scoreboard() -> list[dict]:
    """
    Return list of game dicts for today's NBA slate.
    Each dict: {nba_game_id, home_team_id, away_team_id, home_team_name,
                away_team_name, status, tip_off_utc, nba_date}
    """
    data = await _get(f"{_CDN}/liveData/scoreboard/todaysScoreboard_00.json")
    scoreboard = data.get("scoreboard", {})
    raw_date = scoreboard.get("gameDate", "")
    games = []
    for g in scoreboard.get("games", []):
        games.append(_parse_scoreboard_game(g, raw_date))
    return games


# ---------------------------------------------------------------------------
# Schedule (for a specific date)
# ---------------------------------------------------------------------------

async def fetch_schedule_for_date(nba_date: date) -> list[dict]:
    """
    Return game dicts for a specific NBA date from the full season schedule.
    nba_date is the NBA game date in ET (e.g. 2026-06-13).
    """
    data = await _get(f"{_CDN}/staticData/scheduleLeagueV2_1.json")
    target = nba_date.strftime("%m/%d/%Y")  # schedule uses MM/DD/YYYY

    games = []
    for day in data.get("leagueSchedule", {}).get("gameDates", []):
        # gameDate is "06/13/2026 00:00:00" (MM/DD/YYYY)
        day_str = day.get("gameDate", "")
        try:
            day_date = datetime.strptime(day_str[:10], "%m/%d/%Y").date()
        except ValueError:
            continue
        if day_date != nba_date:
            continue
        for g in day.get("games", []):
            games.append(_parse_schedule_game(g, nba_date))
        break

    return games


# ---------------------------------------------------------------------------
# Boxscore
# ---------------------------------------------------------------------------

async def fetch_boxscore(nba_game_id: str) -> dict | None:
    """
    Return parsed boxscore dict:
      {game_id, nba_date, status, home_team_id, away_team_id,
       home_score, away_score, players: [{...}]}
    Returns None on error.
    """
    try:
        data = await _get(f"{_CDN}/liveData/boxscore/boxscore_{nba_game_id}.json")
    except httpx.HTTPError as exc:
        logger.error("NBA CDN boxscore fetch failed game=%s: %s", nba_game_id, exc)
        return None

    game = data.get("game", {})
    status_int = game.get("gameStatus", 0)

    # Parse NBA date from gameEt (ET game date, e.g. "2026-06-10T20:30:00-04:00")
    nba_date = _parse_et_date(game.get("gameEt", ""))
    tip_off_utc = _parse_utc_time(game.get("gameTimeUTC", ""))

    home = game.get("homeTeam", {})
    away = game.get("awayTeam", {})

    players: list[dict] = []
    for team_side, team_obj in (("home", home), ("away", away)):
        team_id = str(team_obj.get("teamId", ""))
        for p in team_obj.get("players", []):
            players.append(_parse_boxscore_player(p, nba_game_id, team_id, nba_date))

    return {
        "nba_game_id": nba_game_id,
        "nba_date": nba_date,
        "status": STATUS_MAP.get(status_int, "scheduled"),
        "home_team_id": str(home.get("teamId", "")),
        "away_team_id": str(away.get("teamId", "")),
        "home_team_name": f"{home.get('teamCity','')} {home.get('teamName','')}".strip(),
        "away_team_name": f"{away.get('teamCity','')} {away.get('teamName','')}".strip(),
        "home_score": home.get("score"),
        "away_score": away.get("score"),
        "tip_off_utc": tip_off_utc,
        "players": players,
    }


# ---------------------------------------------------------------------------
# Player roster
# ---------------------------------------------------------------------------

async def fetch_player_index() -> list[dict]:
    """
    Return list of active player dicts from NBA playerIndex.
    Each dict: {nba_player_id, first_name, last_name, full_name,
                team_id, team_city, team_name, position, jersey_number,
                height, weight, is_active}
    """
    data = await _get(f"{_CDN}/staticData/playerIndex.json")
    result_set = data.get("resultSets", [{}])[0]
    headers: list[str] = result_set.get("headers", [])
    rows: list[list] = result_set.get("rowSet", [])

    idx = {h: i for i, h in enumerate(headers)}
    players = []
    for row in rows:
        def _col(name: str):
            i = idx.get(name)
            return row[i] if i is not None else None

        roster_status = _col("ROSTER_STATUS")
        is_active = roster_status == 1.0 or roster_status == "1.0"

        players.append({
            "nba_player_id": str(_col("PERSON_ID") or ""),
            "first_name": _col("PLAYER_FIRST_NAME") or "",
            "last_name": _col("PLAYER_LAST_NAME") or "",
            "full_name": f"{_col('PLAYER_FIRST_NAME') or ''} {_col('PLAYER_LAST_NAME') or ''}".strip(),
            "team_id": str(_col("TEAM_ID") or ""),
            "team_city": _col("TEAM_CITY") or "",
            "team_name": _col("TEAM_NAME") or "",
            "position": _col("POSITION") or "",
            "jersey_number": str(_col("JERSEY_NUMBER") or ""),
            "height": _col("HEIGHT") or "",
            "weight": str(_col("WEIGHT") or ""),
            "is_active": is_active,
        })
    return players


# ---------------------------------------------------------------------------
# Internal parsers
# ---------------------------------------------------------------------------

def _parse_scoreboard_game(g: dict, raw_date: str) -> dict:
    status_int = g.get("gameStatus", 0)
    home = g.get("homeTeam", {})
    away = g.get("awayTeam", {})
    tip_off_utc = _parse_utc_time(g.get("gameTimeUTC", ""))
    nba_date = _parse_simple_date(raw_date)
    return {
        "nba_game_id": g.get("gameId", ""),
        "nba_date": nba_date,
        "status": STATUS_MAP.get(status_int, "scheduled"),
        "home_team_id": str(home.get("teamId", "")),
        "away_team_id": str(away.get("teamId", "")),
        "home_team_name": f"{home.get('teamCity','')} {home.get('teamName','')}".strip(),
        "away_team_name": f"{away.get('teamCity','')} {away.get('teamName','')}".strip(),
        "home_score": home.get("score"),
        "away_score": away.get("score"),
        "tip_off_utc": tip_off_utc,
    }


def _parse_schedule_game(g: dict, nba_date: date) -> dict:
    status_int = g.get("gameStatus", 0)
    home = g.get("homeTeam", {})
    away = g.get("awayTeam", {})
    tip_off_utc = _parse_schedule_tip_off(g.get("gameDateTimeUTC") or g.get("gameTimeUTC", ""), nba_date)
    return {
        "nba_game_id": g.get("gameId", ""),
        "nba_date": nba_date,
        "status": STATUS_MAP.get(status_int, "scheduled"),
        "home_team_id": str(home.get("teamId", "")),
        "away_team_id": str(away.get("teamId", "")),
        "home_team_name": f"{home.get('teamCity','')} {home.get('teamName','')}".strip(),
        "away_team_name": f"{away.get('teamCity','')} {away.get('teamName','')}".strip(),
        "home_score": None,
        "away_score": None,
        "tip_off_utc": tip_off_utc,
    }


def _parse_boxscore_player(p: dict, game_id: str, team_id: str, nba_date: date | None) -> dict:
    stats = p.get("statistics", {})
    played = p.get("played", "0") == "1"
    minutes = _parse_minutes_iso(stats.get("minutes", "PT0M"))

    return {
        "nba_player_id": str(p.get("personId", "")),
        "nba_game_id": game_id,
        "nba_date": nba_date,
        "team_id": team_id,
        "name": p.get("name", ""),
        "position": p.get("position", ""),
        "did_not_play": not played or minutes == 0,
        "minutes_played": minutes,
        "points": stats.get("points", 0) or 0,
        "rebounds": stats.get("reboundsTotal", 0) or 0,
        "assists": stats.get("assists", 0) or 0,
        "steals": stats.get("steals", 0) or 0,
        "blocks": stats.get("blocks", 0) or 0,
        "turnovers": stats.get("turnovers", 0) or 0,
        "field_goals_made": stats.get("fieldGoalsMade", 0) or 0,
        "field_goals_attempted": stats.get("fieldGoalsAttempted", 0) or 0,
        "threepoint_made": stats.get("threePointersMade", 0) or 0,
        "threepoint_attempted": stats.get("threePointersAttempted", 0) or 0,
        "freethrow_made": stats.get("freeThrowsMade", 0) or 0,
        "freethrow_attempted": stats.get("freeThrowsAttempted", 0) or 0,
    }


# ---------------------------------------------------------------------------
# Date/time helpers
# ---------------------------------------------------------------------------

def _parse_et_date(et_str: str) -> date | None:
    """Parse '2026-06-10T20:30:00-04:00' → date(2026, 6, 10)."""
    if not et_str:
        return None
    try:
        return datetime.fromisoformat(et_str).date()
    except ValueError:
        return None


def _parse_utc_time(utc_str: str) -> datetime | None:
    """Parse '2026-06-11T00:30:00Z' → aware UTC datetime."""
    if not utc_str:
        return None
    try:
        dt = datetime.fromisoformat(utc_str.replace("Z", "+00:00"))
        # Reject 1900 placeholder dates from schedule
        if dt.year < 2000:
            return None
        return dt.astimezone(timezone.utc)
    except ValueError:
        return None


def _parse_simple_date(date_str: str) -> date | None:
    """Parse '2026-06-11' → date(2026, 6, 11)."""
    if not date_str:
        return None
    try:
        return datetime.strptime(date_str[:10], "%Y-%m-%d").date()
    except ValueError:
        return None


def _parse_schedule_tip_off(time_str: str, nba_date: date) -> datetime | None:
    """
    Schedule gameTimeUTC contains a 1900 placeholder like '1900-01-01T00:30:00Z'.
    Combine with the actual nba_date to get the real UTC datetime.
    """
    if not time_str:
        return None
    try:
        placeholder = datetime.fromisoformat(time_str.replace("Z", "+00:00"))
        # Reconstruct with the real date
        real = placeholder.replace(year=nba_date.year, month=nba_date.month, day=nba_date.day)
        return real.astimezone(timezone.utc)
    except ValueError:
        return None


def _parse_minutes_iso(minutes_str: str) -> int:
    """Parse 'PT41M28.00S' or 'PT41M' → 41."""
    if not minutes_str:
        return 0
    m = re.search(r"PT(\d+)M", minutes_str)
    return int(m.group(1)) if m else 0

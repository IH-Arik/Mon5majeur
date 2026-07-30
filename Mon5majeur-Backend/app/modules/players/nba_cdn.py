"""
NBA CDN player roster client — best-effort only.

Schedule, scores, and box scores now come from the real Goalserve API (see
goalserve_client.py) — the subscription is active and reliable. This module
is kept solely because no Goalserve roster/squad feed could be found for
this account (see goalserve_client.py's module docstring); cdn.nba.com's
playerIndex is used to catch a brand-new signee/rookie before their first
tracked game. It's not reliable either — cdn.nba.com's Akamai edge blocks
most requests with an intermittent, non-deterministic 403 — callers already
treat a failure here as a no-op (see PlayerService.sync_from_goalserve),
since sync_scores_for_date creates/matches players from real box scores
regardless, for anyone who's played at least once.
"""
from __future__ import annotations

import httpx

_CDN = "https://cdn.nba.com/static/json"
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nba.com/",
    "Origin": "https://www.nba.com",
    "Connection": "keep-alive",
}


async def _get(url: str) -> dict:
    async with httpx.AsyncClient(timeout=20, headers=_HEADERS) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        return resp.json()


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

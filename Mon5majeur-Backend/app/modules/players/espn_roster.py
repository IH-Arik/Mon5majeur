"""
ESPN public roster client — reliable fallback for the NBA roster.

Why this exists (QA 15/09/2026 item 2): Goalserve exposes no roster feed on
our account and cdn.nba.com answers 403 to cloud hosts, so the daily roster
sync was silently a no-op and trades / free-agency moves / rookies never
reached the Player collection. ESPN's site API needs no key and returns the
30 teams with their current rosters.

Only identity + team + bio fields are read. Player *ids* from ESPN are used
solely as a placeholder `goalserve_id` ("espn:<id>") for brand-new players;
the first box score re-keys them to the real Goalserve id (see
PlayerService._resolve_goalserve_player).
"""
from __future__ import annotations

import asyncio
import re
import unicodedata

import httpx

_BASE = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba"
# ESPN's edge 403s browser-style and custom User-Agent strings but serves the
# library default (verified 2026-09), so deliberately send NO User-Agent
# override here.
_HEADERS = {"Accept": "application/json"}

_SUFFIXES = {"jr", "sr", "ii", "iii", "iv", "v"}


def normalize_name(name: str) -> str:
    """Accent-, case-, punctuation- and suffix-insensitive key so
    "Nikola Jokić" == "Nikola Jokic" and "Jaren Jackson Jr." == "Jaren
    Jackson"."""
    folded = unicodedata.normalize("NFKD", name or "")
    folded = "".join(c for c in folded if not unicodedata.combining(c)).lower()
    folded = re.sub(r"[^a-z0-9 ]+", " ", folded)
    parts = [p for p in folded.split() if p not in _SUFFIXES]
    return " ".join(parts)


async def _get(client: httpx.AsyncClient, path: str) -> dict:
    resp = await client.get(f"{_BASE}{path}")
    resp.raise_for_status()
    return resp.json()


async def fetch_rosters() -> list[dict]:
    """Return one dict per rostered player:
    {espn_id, first_name, last_name, full_name, team_name, position,
     jersey_number, height, weight}. Teams that fail to load are skipped and
    reported by their absence — the caller checks the team count before
    trusting the result for anything destructive."""
    players: list[dict] = []
    async with httpx.AsyncClient(timeout=20, headers=_HEADERS) as client:
        teams_json = await _get(client, "/teams?limit=40")
        teams = [t["team"] for t in teams_json["sports"][0]["leagues"][0]["teams"]]

        sem = asyncio.Semaphore(6)

        async def _one(team: dict) -> list[dict]:
            async with sem:
                try:
                    data = await _get(client, f"/teams/{team['id']}/roster")
                except Exception:  # noqa: BLE001 — one bad team must not sink the sync
                    return []
            out = []
            for a in data.get("athletes", []):
                full = (a.get("fullName") or a.get("displayName") or "").strip()
                if not full:
                    continue
                out.append(
                    {
                        "espn_id": str(a.get("id") or ""),
                        "first_name": (a.get("firstName") or full.split(" ", 1)[0]).strip(),
                        "last_name": (
                            a.get("lastName") or (full.split(" ", 1)[1] if " " in full else "")
                        ).strip(),
                        "full_name": full,
                        "team_name": team.get("displayName") or "",
                        "position": (a.get("position") or {}).get("abbreviation") or "",
                        "jersey_number": str(a.get("jersey") or ""),
                        "height": a.get("displayHeight") or "",
                        "weight": a.get("displayWeight") or "",
                    }
                )
            return out

        for chunk in await asyncio.gather(*[_one(t) for t in teams]):
            players.extend(chunk)
    return players

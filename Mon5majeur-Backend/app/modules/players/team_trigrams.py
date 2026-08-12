"""
Team name -> NBA display trigram (spec Part 1 §2.0 — "Team trigram mapping
table"). The spec frames this as `goalserve_team_id -> display_trigram`,
but in this backend `team_goalserve_id` is Goalserve's raw internal team
id (a numeric string with no NBA meaning — see goalserve_client.py's
`_team_dict`, which reads it from the XML `id` attribute). The reliable,
human-meaningful field Goalserve actually gives us is the team NAME
(`team_name` / `home_team_name` / `away_team_name`), so the mapping here
is keyed by name instead. Same requirement either way: never show a raw
Goalserve identifier, always show the correct uppercase NBA trigram.
"""
from __future__ import annotations

_TEAM_NAME_TO_TRIGRAM: dict[str, str] = {
    "Atlanta Hawks": "ATL",
    "Boston Celtics": "BOS",
    "Brooklyn Nets": "BKN",
    "Charlotte Hornets": "CHA",
    "Chicago Bulls": "CHI",
    "Cleveland Cavaliers": "CLE",
    "Dallas Mavericks": "DAL",
    "Denver Nuggets": "DEN",
    "Detroit Pistons": "DET",
    "Golden State Warriors": "GSW",
    "Houston Rockets": "HOU",
    "Indiana Pacers": "IND",
    "LA Clippers": "LAC",
    "Los Angeles Clippers": "LAC",
    "Los Angeles Lakers": "LAL",
    "Memphis Grizzlies": "MEM",
    "Miami Heat": "MIA",
    "Milwaukee Bucks": "MIL",
    "Minnesota Timberwolves": "MIN",
    "New Orleans Pelicans": "NOP",
    "New York Knicks": "NYK",
    "Oklahoma City Thunder": "OKC",
    "Orlando Magic": "ORL",
    "Philadelphia 76ers": "PHI",
    "Phoenix Suns": "PHX",
    "Portland Trail Blazers": "POR",
    "Portland TrailBlazers": "POR",
    "Sacramento Kings": "SAC",
    "San Antonio Spurs": "SAS",
    "Toronto Raptors": "TOR",
    "Utah Jazz": "UTA",
    "Washington Wizards": "WAS",
}


def trigram_for_team_name(team_name: str | None) -> str | None:
    """Uppercase 3-letter trigram for a team full name, or None if the name
    doesn't match (never falls back to a raw Goalserve id — an unmapped
    team is better shown as absent than wrong, spec §2.0)."""
    if not team_name:
        return None
    return _TEAM_NAME_TO_TRIGRAM.get(team_name.strip())

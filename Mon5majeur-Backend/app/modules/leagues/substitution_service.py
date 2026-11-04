"""
Database side of the substitute rule: reads the minutes, calls the pure
``apply_substitution`` and hands back the five starters that count.
"""
from __future__ import annotations

from datetime import date, datetime

from beanie import PydanticObjectId

from app.modules.leagues.substitution import SubstitutionResult, apply_substitution
from app.modules.players.model import PlayerGameStats


async def substitution_at_close(sel, nba_date: date) -> SubstitutionResult:
    """Decision for a night that is being closed. A player with no stat row
    (game not final, e.g. postponed) counts as 0 minute, so the substitution
    applies normally."""
    sub = getattr(sel, "substitute_player", None)
    people = list(sel.selected_players) + ([sub] if sub is not None else [])
    oids = []
    for p in people:
        try:
            oids.append(PydanticObjectId(str(p.get("id", ""))))
        except Exception:
            pass
    rows = await PlayerGameStats.find(
        {"player_id": {"$in": oids}, "nba_date": datetime.combine(nba_date, datetime.min.time())}
    ).to_list() if oids and sub is not None else []
    minutes = {str(r.player_id): 0 if r.did_not_play else (r.minutes_played or 0) for r in rows}
    return apply_substitution(sel.selected_players, sub, minutes, settled=True)


async def counted_starters(sel, nba_date: date) -> list[dict]:
    """The five players whose scores count for a closed night. A lineup without
    a substitute is returned as saved, with no extra query."""
    if getattr(sel, "substitute_player", None) is None:
        return sel.selected_players
    return (await substitution_at_close(sel, nba_date)).starters

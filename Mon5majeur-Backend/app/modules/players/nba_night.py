"""The NBA "night" a moment belongs to.

NBA games are dated by their US date, and a night's games run from Paris
evening D until Paris morning D+1 - i.e. past midnight UTC. The plain UTC
date is therefore WRONG for the small hours (at 03:00 Paris it is already D+1
while the games being played are still night D). The rule used across the app
(see compat_router._nba_today): the UTC date if it has games in the DB,
otherwise the day before.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from app.modules.players.model import NBAGame


async def current_nba_night() -> date:
    utc_today = datetime.now(timezone.utc).date()
    for candidate in (utc_today, utc_today - timedelta(days=1)):
        if await NBAGame.find(NBAGame.nba_date == candidate).count() > 0:
            return candidate
    return utc_today


async def latest_finished_night(today: date) -> date | None:
    """Most recent night strictly before `today` that has games."""
    game = (
        await NBAGame.find(NBAGame.nba_date < today).sort(-NBAGame.nba_date).first_or_none()
    )
    return game.nba_date if game else None

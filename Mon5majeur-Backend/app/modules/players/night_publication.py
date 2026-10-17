"""The moment a night is really published (QA #13 addendum).

The 09:00 Paris cutoff only says when the publication is DUE. A night is
published once the daily close has finished everything (duels, standings,
Global archive, prices): only then does the next day open, everywhere at once.
If the close is late, lineups stay locked until it is done (see
nba_night.is_published for the safety grace).
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from beanie import Document
from pymongo import ASCENDING, IndexModel


class NightPublication(Document):
    night: date
    published_at: datetime

    class Settings:
        name = "night_publications"
        indexes = [IndexModel([("night", ASCENDING)], unique=True)]


async def mark_published(night: date) -> None:
    """Record that `night` is published (idempotent)."""
    existing = await NightPublication.find_one(NightPublication.night == night)
    if existing:
        return
    await NightPublication(night=night, published_at=datetime.now(timezone.utc)).insert()


async def published_marks(nights: list[date]) -> set[date]:
    if not nights:
        return set()
    rows = await NightPublication.find({"night": {"$in": list(nights)}}).to_list()
    return {r.night for r in rows}

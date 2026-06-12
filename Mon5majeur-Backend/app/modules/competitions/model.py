from datetime import datetime
from typing import Literal

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument
from app.modules.competitions.constants import STATUS_UPCOMING


class Competition(BaseDocument):
    name: str
    description: str | None = None
    league: str = "nba"

    status: str = STATUS_UPCOMING
    start_date: datetime
    end_date: datetime

    entry_fee: float = 0.0          # 0 = free contest
    max_entries: int | None = None  # None = unlimited
    prize_pool: float = 0.0
    prize_description: str | None = None

    entry_count: int = 0
    created_by: PydanticObjectId | None = None  # admin who created it

    class Settings:
        name = "competitions"
        indexes = [
            IndexModel([("status", ASCENDING)]),
            IndexModel([("start_date", ASCENDING)]),
            IndexModel([("league", ASCENDING)]),
        ]


class CompetitionEntry(BaseDocument):
    """A user's team entry into a competition."""
    competition_id: PydanticObjectId
    user_id: PydanticObjectId
    team_id: PydanticObjectId
    rank: int | None = None
    score: float = 0.0

    class Settings:
        name = "competition_entries"
        indexes = [
            IndexModel([("competition_id", ASCENDING), ("user_id", ASCENDING)], unique=True),
            IndexModel([("competition_id", ASCENDING), ("score", ASCENDING)]),
        ]

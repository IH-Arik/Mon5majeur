from datetime import date

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class GlobalLeagueDailyScore(BaseDocument):
    """
    Immutable per-user, per-night fantasy score for the NBA Global League.

    Written once by the 09:00 Paris daily-close job for the NBA date whose
    games just finished. Backs the Weekly/Monthly rank shown on the Home
    "NBA Global League" card — summed over the current ISO week / calendar
    month across all Global League members.
    """
    user_id: PydanticObjectId
    league_id: PydanticObjectId
    nba_date: date
    total_points: float = 0.0

    class Settings:
        name = "global_league_daily_scores"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("league_id", ASCENDING), ("nba_date", ASCENDING)],
                unique=True,
            ),
            IndexModel([("league_id", ASCENDING), ("nba_date", ASCENDING)]),
        ]

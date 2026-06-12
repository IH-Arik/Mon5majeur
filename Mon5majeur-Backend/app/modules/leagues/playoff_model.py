from datetime import date
from typing import Literal

from beanie import PydanticObjectId
from pydantic import BaseModel
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class PlayoffGame(BaseModel):
    """One individual game within a BO3 playoff series."""
    game_number: int
    score_a: float = 0.0
    score_b: float = 0.0
    nba_date: date | None = None
    winner_id: PydanticObjectId | None = None


class PlayoffSeries(BaseDocument):
    """
    One BO3 series in the playoff bracket.
    Created by the start_playoffs engine when league transitions to playoffs.
    """
    league_id: PydanticObjectId
    round: Literal["quarter_final", "semi_final", "final"]
    series_index: int = 0       # 0-based index within the round (for bracket ordering)

    team_a_id: PydanticObjectId
    team_b_id: PydanticObjectId

    wins_a: int = 0
    wins_b: int = 0
    games: list[PlayoffGame] = []

    winner_id: PydanticObjectId | None = None
    is_complete: bool = False

    class Settings:
        name = "playoff_series"
        indexes = [
            IndexModel([("league_id", ASCENDING), ("round", ASCENDING)]),
            IndexModel([("league_id", ASCENDING), ("team_a_id", ASCENDING)]),
            IndexModel([("league_id", ASCENDING), ("team_b_id", ASCENDING)]),
        ]

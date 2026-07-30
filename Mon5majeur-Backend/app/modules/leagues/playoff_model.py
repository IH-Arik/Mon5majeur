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
    Created by the playoff_engine when the league transitions to playoffs
    (semi_final) and again once both semis are complete (final) — spec
    §4.6.3 is Top-4 seeded straight into semifinals, there is no quarter-final.
    """
    league_id: PydanticObjectId
    round: Literal["semi_final", "final"]
    series_index: int = 0       # 0-based index within the round (for bracket ordering)

    # team_a is always the higher (better) regular-season seed — a fixed
    # identity for the series, independent of which side is "home" in a
    # given game (home alternates per spec's playoff_home rule).
    team_a_id: PydanticObjectId
    team_b_id: PydanticObjectId
    seed_a: int | None = None
    seed_b: int | None = None

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

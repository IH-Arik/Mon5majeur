from datetime import date, datetime
from typing import Literal

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


# Lineup slots: exactly 5 positions
SLOT_NAMES = Literal["PG", "SG", "SF", "PF", "C"]


class LineupSlot(BaseDocument):
    """
    One player assignment in a user's daily lineup for a given league.
    One row per slot (PG/SG/SF/PF/C). Together the 5 rows = one lineup.
    """
    user_id: PydanticObjectId
    league_id: PydanticObjectId
    nba_date: date
    slot: str                              # "PG" | "SG" | "SF" | "PF" | "C"
    player_id: PydanticObjectId
    player_goalserve_id: str
    player_name: str
    player_position: str
    player_price: float                    # price locked at submission time

    # Filled after game is final
    fantasy_score: float | None = None
    score_finalized: bool = False

    # 6th Man bonus flag (set by bonus engine)
    is_sixth_man: bool = False

    class Settings:
        name = "lineup_slots"
        indexes = [
            # One slot per position per user per league per day
            IndexModel(
                [("user_id", ASCENDING), ("league_id", ASCENDING),
                 ("nba_date", ASCENDING), ("slot", ASCENDING)],
                unique=True,
            ),
            IndexModel([("league_id", ASCENDING), ("nba_date", ASCENDING)]),
            IndexModel([("user_id", ASCENDING), ("nba_date", ASCENDING)]),
            IndexModel([("score_finalized", ASCENDING)]),
        ]


class LineupSubmission(BaseDocument):
    """
    Header record for a complete 5-slot lineup submission.
    Used to track lock status, bonus activations, and total score.
    """
    user_id: PydanticObjectId
    league_id: PydanticObjectId
    nba_date: date
    submitted_at: datetime
    is_locked: bool = False
    locked_at: datetime | None = None

    # Total fantasy score (sum of slots, after bonuses applied)
    total_score: float | None = None
    score_finalized: bool = False

    # Active bonuses for this lineup
    luxury_tax_used: bool = False          # +5M budget bonus
    chef_curry_used: bool = False          # +3pts bonus
    sixth_man_used: bool = False           # top-5-of-6 bonus

    class Settings:
        name = "lineup_submissions"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("league_id", ASCENDING), ("nba_date", ASCENDING)],
                unique=True,
            ),
            IndexModel([("league_id", ASCENDING), ("nba_date", ASCENDING)]),
            IndexModel([("score_finalized", ASCENDING)]),
            IndexModel([("is_locked", ASCENDING)]),
        ]

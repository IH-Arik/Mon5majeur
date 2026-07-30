import secrets
from datetime import date, datetime
from typing import Literal

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument
from app.modules.leagues.constants import (
    BUDGET_PREMIUM,
    LEAGUE_STATUS_WAITING,
    LEAGUE_TYPE_PRIVATE,
    MATCH_STATUS_UPCOMING,
)


class League(BaseDocument):
    name: str
    type: Literal["global", "private", "public"]
    status: Literal["waiting", "regular_season", "playoffs", "completed", "cancelled"] = LEAGUE_STATUS_WAITING

    budget: int = BUDGET_PREMIUM          # millions (80 or 100)
    max_size: int = 10                    # 4, 6, 8, 10
    current_size: int = 0

    invite_code: str | None = None        # private leagues only
    admin_id: PydanticObjectId | None = None

    current_match_day: int = 0
    current_week: int = 0
    total_match_days: int = 0             # set at start_league

    started_at: datetime | None = None
    ended_at: datetime | None = None

    # Flutter-compat: sequential integer ID (assigned at creation via counters collection)
    auto_id: int | None = None
    description: str = ""
    logo: str = ""

    class Settings:
        name = "leagues"
        indexes = [
            IndexModel([("type", ASCENDING)]),
            IndexModel([("status", ASCENDING)]),
            # Partial unique index — only enforces uniqueness when invite_code is a string
            IndexModel(
                [("invite_code", ASCENDING)],
                unique=True,
                partialFilterExpression={"invite_code": {"$type": "string"}},
            ),
            IndexModel([("auto_id", ASCENDING)], sparse=True),
        ]

    @classmethod
    def generate_invite_code(cls) -> str:
        return secrets.token_urlsafe(6).upper()


class LeagueMembership(BaseDocument):
    """One row per user per league."""
    league_id: PydanticObjectId
    user_id: PydanticObjectId

    rank: int | None = None
    wins: int = 0
    losses: int = 0
    points_for: float = 0.0      # total fantasy points scored
    points_against: float = 0.0  # total fantasy points conceded

    class Settings:
        name = "league_memberships"
        indexes = [
            IndexModel([("league_id", ASCENDING), ("user_id", ASCENDING)], unique=True),
            IndexModel([("user_id", ASCENDING)]),
            IndexModel([("league_id", ASCENDING), ("rank", ASCENDING)]),
        ]

    @property
    def differential(self) -> float:
        return self.points_for - self.points_against


class LeagueMatch(BaseDocument):
    """A single duel between two users on one match_day."""
    league_id: PydanticObjectId
    match_day: int
    nba_date: date                          # US/EST date from Goalserve

    home_user_id: PydanticObjectId
    away_user_id: PydanticObjectId

    home_score: float | None = None
    away_score: float | None = None
    winner_id: PydanticObjectId | None = None

    status: Literal["upcoming", "live", "completed"] = MATCH_STATUS_UPCOMING

    # Sequential integer ID for Flutter compat (Flutter's int id field)
    auto_id: int | None = None

    # Bonus flags (applied at scoring)
    home_chef_curry_used: bool = False
    away_chef_curry_used: bool = False

    # Playoffs (spec §4.6.3) — reuses the regular-season lineup/lock/budget
    # pipeline for playoff games too, just tagged with which series/game this
    # is and each side's frozen regular-season seed (1-4, for the seeding
    # budget bonus applied at lineup-save time).
    is_playoff: bool = False
    playoff_series_id: PydanticObjectId | None = None
    playoff_game_number: int | None = None
    home_seed: int | None = None
    away_seed: int | None = None

    class Settings:
        name = "league_matches"
        indexes = [
            IndexModel([("league_id", ASCENDING), ("match_day", ASCENDING)]),
            IndexModel([("home_user_id", ASCENDING), ("nba_date", ASCENDING)]),
            IndexModel([("away_user_id", ASCENDING), ("nba_date", ASCENDING)]),
            IndexModel([("nba_date", ASCENDING), ("status", ASCENDING)]),
            IndexModel([("auto_id", ASCENDING)], sparse=True),
        ]

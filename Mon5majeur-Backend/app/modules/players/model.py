from datetime import date, datetime
from typing import Literal

from beanie import Indexed, PydanticObjectId
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.database.base import BaseDocument


class Player(BaseDocument):
    """Cached NBA player data synced from Goalserve."""
    goalserve_id: Indexed(str, unique=True)  # type: ignore[valid-type]
    first_name: str
    last_name: str
    full_name: str
    position: str | None = None             # PG, SG, SF, PF, C
    team_name: str | None = None
    team_goalserve_id: str | None = None
    league: str = "nba"
    nationality: str | None = None
    birth_date: str | None = None
    height: str | None = None
    weight: str | None = None
    jersey_number: str | None = None
    image_url: str | None = None
    is_active: bool = True

    # Injury / availability
    is_out: bool = False
    out_reason: str | None = None           # "sidelined", "will not play", etc.
    injury_checked_at: datetime | None = None

    # Pricing (recomputed daily at 09:00 Paris)
    daily_price: float = 3.0                # in millions
    price_computed_at: date | None = None   # date of last price compute

    # Fantasy stats cache
    avg_fantasy_score: float = 0.0          # rolling average (for display)
    games_played: int = 0

    # Form indicator (spec Part 1 §4.0) — relative ranking within tonight's
    # eligible pool, recomputed once daily in the same cron pass as pricing
    # (see form_indicator.py). "HOT" | "COLD" | None (= neutral, no badge).
    form: str | None = None

    # Last 2 played-game Fantasy Scores (spec Part 1 §5.0), chronological
    # [older, newer]. None in a slot = no played game there (never 0/X).
    # Same played-games source as `form`, computed alongside pricing.
    recent_two_scores: list[int | None] = [None, None]

    class Settings:
        name = "players"
        indexes = [
            IndexModel([("goalserve_id", ASCENDING)], unique=True),
            IndexModel([("full_name", ASCENDING)]),
            IndexModel([("team_goalserve_id", ASCENDING)]),
            IndexModel([("league", ASCENDING)]),
            IndexModel([("daily_price", DESCENDING)]),
            IndexModel([("is_out", ASCENDING)]),
        ]


class PlayerGameStats(BaseDocument):
    """Per-game stats for one player — source of Fantasy Score computation."""
    player_id: PydanticObjectId
    goalserve_player_id: str
    goalserve_game_id: str
    nba_date: date                          # US/EST date

    # Raw Goalserve stats
    points: int = 0
    rebounds: int = 0
    assists: int = 0
    steals: int = 0
    blocks: int = 0
    turnovers: int = 0

    # Shooting (derived from Goalserve — never use two_pt field)
    field_goals_made: int = 0
    field_goals_attempted: int = 0
    threepoint_made: int = 0
    threepoint_attempted: int = 0
    freethrow_made: int = 0
    freethrow_attempted: int = 0

    # Computed Fantasy Score (stored after computation)
    fantasy_score: float | None = None
    score_computed: bool = False

    # Minutes played (0 = DNP)
    minutes_played: int = 0
    did_not_play: bool = False

    class Settings:
        name = "player_game_stats"
        indexes = [
            IndexModel([("player_id", ASCENDING), ("nba_date", DESCENDING)]),
            IndexModel([("goalserve_game_id", ASCENDING), ("goalserve_player_id", ASCENDING)], unique=True),
            IndexModel([("nba_date", DESCENDING)]),
            IndexModel([("score_computed", ASCENDING)]),
        ]


class NBAGame(BaseDocument):
    """An NBA game (one matchup) from Goalserve."""
    goalserve_id: str
    nba_date: date
    home_team_id: str
    away_team_id: str
    home_team_name: str
    away_team_name: str
    status: Literal["scheduled", "live", "final"] = "scheduled"
    tip_off_time: datetime | None = None    # UTC
    home_score: int | None = None
    away_score: int | None = None

    class Settings:
        name = "nba_games"
        indexes = [
            IndexModel([("goalserve_id", ASCENDING)], unique=True),
            IndexModel([("nba_date", DESCENDING)]),
            IndexModel([("status", ASCENDING)]),
        ]

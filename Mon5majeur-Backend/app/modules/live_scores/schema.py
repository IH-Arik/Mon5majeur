from datetime import datetime

from beanie import PydanticObjectId

from app.shared.base_schema import BaseSchema


class LivePlayerScore(BaseSchema):
    player_id: PydanticObjectId
    full_name: str
    position: str | None
    team_name: str | None
    slot: str

    # Live / current stats
    points: int = 0
    rebounds: int = 0
    assists: int = 0
    steals: int = 0
    blocks: int = 0
    turnovers: int = 0
    minutes_played: int = 0

    fantasy_score_live: float = 0.0
    is_finalized: bool = False
    # False only for the dropped 6th-Man score (spec §4.4: top 5 of 6).
    # Always True when there's no 6th Man.
    is_counted: bool = True
    # Starter replaced by the substitute (greyed, "absent"); never set before
    # every game of the lineup is final.
    is_absent: bool = False


class LiveMatchScore(BaseSchema):
    """Live duel scores for a user's match."""
    match_id: PydanticObjectId
    league_id: PydanticObjectId
    league_name: str
    nba_date: str

    home_user_id: PydanticObjectId
    away_user_id: PydanticObjectId
    home_team_name: str | None
    away_team_name: str | None
    # each team's saved jersey, so the court wears the right one
    home_jersey_index: int = 0
    away_jersey_index: int = 0
    # Saved avatar of each team; "" when the account has none, never null
    # (QA #13 item 5: the Live drew the default devil for both teams).
    home_team_logo: str = ""
    away_team_logo: str = ""

    home_score: float
    away_score: float
    match_status: str   # upcoming | live | completed
    # Live still has this night to show (until the 09:00 publication).
    has_live_games: bool = False

    home_players: list[LivePlayerScore]
    away_players: list[LivePlayerScore]
    # Substitute (lineup rule) of each team: his live line and the state of the
    # substitution. None without a substitute; an opponent's stays None until
    # the first tip-off (lineup information).
    home_substitute: LivePlayerScore | None = None
    away_substitute: LivePlayerScore | None = None
    home_substitution: dict | None = None
    away_substitution: dict | None = None

    is_stale: bool = False
    refreshed_at: datetime


class LiveGlobalScore(BaseSchema):
    """Live Global League score for the current user (no opponent, no bonuses
    — spec §4.4: bonuses aren't available in the Global League)."""
    league_id: PydanticObjectId
    league_name: str

    total_score: float
    players: list[LivePlayerScore]
    substitute: LivePlayerScore | None = None
    substitution: dict | None = None

    # True while at least one NBA game of the day is in progress. The app
    # shows "no live game" instead of a 0-point lineup when it is False.
    has_live_games: bool = False
    is_stale: bool = False
    refreshed_at: datetime


class PremiumStatusResponse(BaseSchema):
    is_premium: bool
    premium_until: datetime | None

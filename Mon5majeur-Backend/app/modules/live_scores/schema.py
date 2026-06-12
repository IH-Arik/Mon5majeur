from datetime import datetime

from beanie import PydanticObjectId
from pydantic import Field

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

    home_score: float
    away_score: float
    match_status: str   # upcoming | live | completed

    home_players: list[LivePlayerScore]
    away_players: list[LivePlayerScore]

    refreshed_at: datetime


class PremiumStatusResponse(BaseSchema):
    is_premium: bool
    premium_until: datetime | None

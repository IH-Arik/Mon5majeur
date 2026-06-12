from datetime import date, datetime

from beanie import PydanticObjectId
from pydantic import Field

from app.shared.base_schema import BaseSchema


class PlayerResponse(BaseSchema):
    id: PydanticObjectId
    goalserve_id: str
    first_name: str
    last_name: str
    full_name: str
    position: str | None
    team_name: str | None
    team_goalserve_id: str | None
    league: str
    nationality: str | None
    height: str | None
    weight: str | None
    jersey_number: str | None
    image_url: str | None
    is_active: bool
    is_out: bool
    out_reason: str | None
    daily_price: float
    avg_fantasy_score: float
    games_played: int


class PlayerSearchParams(BaseSchema):
    q: str | None = Field(None, description="Search by name")
    league: str | None = Field(None, description="nba | euroleague")
    position: str | None = Field(None, description="PG | SG | SF | PF | C")
    team_id: str | None = Field(None, description="Goalserve team ID")


class PlayerGameStatsResponse(BaseSchema):
    id: PydanticObjectId
    player_id: PydanticObjectId
    goalserve_game_id: str
    nba_date: date
    points: int
    rebounds: int
    assists: int
    steals: int
    blocks: int
    turnovers: int
    field_goals_made: int
    field_goals_attempted: int
    threepoint_made: int
    threepoint_attempted: int
    freethrow_made: int
    freethrow_attempted: int
    minutes_played: int
    did_not_play: bool
    fantasy_score: float | None
    score_computed: bool


class NBAGameResponse(BaseSchema):
    id: PydanticObjectId
    goalserve_id: str
    nba_date: date
    home_team_id: str
    away_team_id: str
    home_team_name: str
    away_team_name: str
    status: str
    tip_off_time: datetime | None
    home_score: int | None
    away_score: int | None


class PlayerTodayItem(BaseSchema):
    """Compact player card for lineup picker — today's players only."""
    id: PydanticObjectId
    full_name: str
    position: str | None
    team_name: str | None
    team_goalserve_id: str | None
    image_url: str | None
    is_out: bool
    out_reason: str | None
    daily_price: float
    avg_fantasy_score: float
    game_time: datetime | None
    opponent_team_name: str | None

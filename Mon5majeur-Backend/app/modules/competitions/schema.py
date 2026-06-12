from datetime import datetime

from beanie import PydanticObjectId
from pydantic import field_validator

from app.shared.base_schema import BaseSchema


class CompetitionCreate(BaseSchema):
    name: str
    description: str | None = None
    league: str = "nba"
    start_date: datetime
    end_date: datetime
    entry_fee: float = 0.0
    max_entries: int | None = None
    prize_pool: float = 0.0
    prize_description: str | None = None

    @field_validator("end_date")
    @classmethod
    def end_after_start(cls, v: datetime, info) -> datetime:
        start = info.data.get("start_date")
        if start and v <= start:
            raise ValueError("end_date must be after start_date")
        return v


class CompetitionUpdate(BaseSchema):
    name: str | None = None
    description: str | None = None
    status: str | None = None
    prize_description: str | None = None


class CompetitionResponse(BaseSchema):
    id: PydanticObjectId
    name: str
    description: str | None
    league: str
    status: str
    start_date: datetime
    end_date: datetime
    entry_fee: float
    max_entries: int | None
    prize_pool: float
    prize_description: str | None
    entry_count: int
    created_at: datetime


class CompetitionEntryResponse(BaseSchema):
    id: PydanticObjectId
    competition_id: PydanticObjectId
    user_id: PydanticObjectId
    team_id: PydanticObjectId
    rank: int | None
    score: float
    created_at: datetime


class EnterCompetitionRequest(BaseSchema):
    team_id: PydanticObjectId


class LeaderboardEntry(BaseSchema):
    rank: int
    user_id: PydanticObjectId
    team_id: PydanticObjectId
    score: float

from __future__ import annotations

from datetime import datetime

from beanie import PydanticObjectId
from pydantic import field_validator

from app.modules.fantasy_teams.constants import MAX_TEAM_SIZE
from app.shared.base_schema import BaseSchema


class FantasyTeamCreate(BaseSchema):
    name: str
    player_ids: list[PydanticObjectId]
    competition_id: PydanticObjectId | None = None

    @field_validator("player_ids")
    @classmethod
    def validate_team_size(cls, v: list) -> list:
        if len(v) != MAX_TEAM_SIZE:
            raise ValueError(f"A team must have exactly {MAX_TEAM_SIZE} players")
        if len({str(pid) for pid in v}) != MAX_TEAM_SIZE:
            raise ValueError("Duplicate players are not allowed")
        return v


class FantasyTeamUpdate(BaseSchema):
    name: str | None = None
    player_ids: list[PydanticObjectId] | None = None

    @field_validator("player_ids")
    @classmethod
    def validate_team_size(cls, v: list | None) -> list | None:
        if v is not None and len(v) != MAX_TEAM_SIZE:
            raise ValueError(f"A team must have exactly {MAX_TEAM_SIZE} players")
        return v


class FantasyTeamResponse(BaseSchema):
    id: PydanticObjectId
    owner_id: PydanticObjectId
    name: str
    player_ids: list[PydanticObjectId]
    competition_id: PydanticObjectId | None
    total_fantasy_score: float
    is_submitted: bool
    created_at: datetime
    updated_at: datetime


class FantasyTeamDetailResponse(FantasyTeamResponse):
    players: list = []   # list[PlayerResponse] — hydrated at runtime by service

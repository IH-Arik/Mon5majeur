from datetime import date, datetime

from beanie import PydanticObjectId
from pydantic import Field, model_validator

from app.shared.base_schema import BaseSchema


class LineupSlotInput(BaseSchema):
    slot: str = Field(..., description="PG | SG | SF | PF | C  (or SIXTH_MAN when sixth_man bonus active)")
    player_id: str = Field(..., description="Player MongoDB ObjectId")


class SubmitLineupRequest(BaseSchema):
    league_id: str
    nba_date: date
    slots: list[LineupSlotInput] = Field(..., min_length=5, max_length=6)

    # Optional bonus activations
    luxury_tax: bool = False
    chef_curry: bool = False
    sixth_man: bool = False

    @model_validator(mode="after")
    def validate_slots(self) -> "SubmitLineupRequest":
        from app.modules.lineups.constants import REQUIRED_SLOTS, SIXTH_MAN_SLOT_COUNT, SIXTH_MAN_SLOT_NAME

        slot_names = [s.slot.upper() for s in self.slots]

        if self.sixth_man:
            if len(self.slots) != SIXTH_MAN_SLOT_COUNT:
                raise ValueError("sixth_man bonus requires exactly 6 slots")
            regular = [n for n in slot_names if n != SIXTH_MAN_SLOT_NAME]
            if sorted(regular) != sorted(REQUIRED_SLOTS):
                raise ValueError(f"sixth_man lineup must include all 5 required slots: {REQUIRED_SLOTS}")
            if slot_names.count(SIXTH_MAN_SLOT_NAME) != 1:
                raise ValueError("sixth_man lineup must include exactly one SIXTH_MAN slot")
        else:
            if len(self.slots) != 5:
                raise ValueError("Lineup must have exactly 5 slots")
            if sorted(slot_names) != sorted(REQUIRED_SLOTS):
                raise ValueError(f"Lineup must have exactly one of each: {REQUIRED_SLOTS}")

        if len(set(slot_names)) != len(slot_names):
            raise ValueError("Duplicate slots are not allowed")

        return self


class LineupSlotResponse(BaseSchema):
    id: PydanticObjectId
    slot: str
    player_id: PydanticObjectId
    player_name: str
    player_position: str
    player_price: float
    fantasy_score: float | None
    score_finalized: bool
    is_sixth_man: bool


class LineupSubmissionResponse(BaseSchema):
    id: PydanticObjectId
    user_id: PydanticObjectId
    league_id: PydanticObjectId
    nba_date: date
    submitted_at: datetime
    is_locked: bool
    locked_at: datetime | None
    total_score: float | None
    score_finalized: bool
    luxury_tax_used: bool
    chef_curry_used: bool
    sixth_man_used: bool
    slots: list[LineupSlotResponse]
    total_price: float


class MyLineupTodayResponse(BaseSchema):
    """Full lineup for today — or None if not yet submitted."""
    submitted: bool
    lineup: LineupSubmissionResponse | None = None
    budget_available: float
    lock_deadline: datetime | None = None

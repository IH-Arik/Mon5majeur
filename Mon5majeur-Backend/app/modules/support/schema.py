from datetime import datetime

from beanie import PydanticObjectId
from pydantic import Field

from app.modules.support.model import TicketStatus
from app.shared.base_schema import BaseSchema


# ── Requests ──────────────────────────────────────────────────────────────────

class TicketCreateRequest(BaseSchema):
    subject: str = Field(min_length=3, max_length=200)
    message: str = Field(min_length=1, max_length=5000)


class TicketReplyRequest(BaseSchema):
    message: str = Field(min_length=1, max_length=5000)


class TicketStatusUpdateRequest(BaseSchema):
    status: TicketStatus


# ── Responses ─────────────────────────────────────────────────────────────────

class TicketMessageResponse(BaseSchema):
    body: str
    author_is_admin: bool
    author_name: str = ""
    sent_at: datetime


class TicketSummaryResponse(BaseSchema):
    """List-row shape: no messages, so a long thread never bloats the list."""

    id: PydanticObjectId
    subject: str
    status: TicketStatus
    user_email: str
    user_name: str = ""
    message_count: int
    # Whether the last word was the player's — the dashboard sorts and
    # highlights on this, since those are the tickets actually awaiting a reply.
    awaiting_admin: bool
    created_at: datetime
    last_activity_at: datetime


class TicketDetailResponse(TicketSummaryResponse):
    messages: list[TicketMessageResponse]


class TicketListResponse(BaseSchema):
    total: int
    page: int
    size: int
    items: list[TicketSummaryResponse]


class TicketCountersResponse(BaseSchema):
    """Stat cards above the dashboard's ticket table."""

    open: int = 0
    pending: int = 0
    resolved: int = 0
    closed: int = 0
    awaiting_admin: int = 0

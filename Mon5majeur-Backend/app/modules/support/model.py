"""
Support tickets: a player raises one from the app, an admin answers it from
the dashboard.

The conversation lives inside the ticket as an embedded list rather than in
its own collection. A thread is always read in full and never queried on its
own, so embedding keeps a ticket to a single read and removes the chance of
messages orphaned from a deleted ticket.
"""
from datetime import datetime, timezone
from typing import Literal

from beanie import PydanticObjectId
from pydantic import BaseModel, Field
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.database.base import BaseDocument

TicketStatus = Literal["open", "pending", "resolved", "closed"]
TICKET_STATUSES: tuple[str, ...] = ("open", "pending", "resolved", "closed")

# "open"     — raised by the player, nobody has replied yet
# "pending"  — an admin replied; waiting on the player
# "resolved" — the admin considers it handled; the player can still reply
# "closed"   — finished; no further replies accepted


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TicketMessage(BaseModel):
    """One entry in the conversation.

    `author_is_admin` rather than a user id: it is the only distinction the
    UI draws, and it survives the author's account being deleted, which
    would otherwise leave a message that cannot be attributed.
    """

    body: str
    author_is_admin: bool
    author_name: str = ""
    sent_at: datetime = Field(default_factory=_utcnow)


class SupportTicket(BaseDocument):
    user_id: PydanticObjectId
    user_email: str          # copied at creation so the thread stays readable
    user_name: str = ""      # if the account is later deleted or anonymised
    subject: str
    status: TicketStatus = "open"
    messages: list[TicketMessage] = Field(default_factory=list)

    # Bumped on every message so the dashboard can sort by "needs attention"
    # without walking the embedded list.
    last_activity_at: datetime = Field(default_factory=_utcnow)

    class Settings:
        name = "support_tickets"
        indexes = [
            IndexModel([("status", ASCENDING), ("last_activity_at", DESCENDING)]),
            IndexModel([("user_id", ASCENDING), ("last_activity_at", DESCENDING)]),
        ]

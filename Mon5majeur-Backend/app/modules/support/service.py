"""
Support ticket operations, shared by the player-facing and admin routers so
the two can never drift on what a reply does to a ticket's status.
"""
from __future__ import annotations

from datetime import datetime, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import BadRequestException, NotFoundException
from app.modules.support.model import (
    SupportTicket,
    TicketMessage,
    TicketStatus,
)
from app.modules.support.schema import (
    TicketCountersResponse,
    TicketDetailResponse,
    TicketListResponse,
    TicketSummaryResponse,
)
from app.modules.users.model import User


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _awaiting_admin(ticket: SupportTicket) -> bool:
    """True when the player spoke last and the ticket is still live.

    A closed ticket never awaits anyone, so it stays out of the "needs a
    reply" count even though its final message came from the player.
    """
    if ticket.status == "closed":
        return False
    if not ticket.messages:
        return False
    return not ticket.messages[-1].author_is_admin


def _to_summary(ticket: SupportTicket) -> TicketSummaryResponse:
    return TicketSummaryResponse(
        id=ticket.id,
        subject=ticket.subject,
        status=ticket.status,
        user_email=ticket.user_email,
        user_name=ticket.user_name,
        message_count=len(ticket.messages),
        awaiting_admin=_awaiting_admin(ticket),
        created_at=ticket.created_at,
        last_activity_at=ticket.last_activity_at,
    )


def _to_detail(ticket: SupportTicket) -> TicketDetailResponse:
    return TicketDetailResponse(
        **_to_summary(ticket).model_dump(),
        messages=[m.model_dump() for m in ticket.messages],
    )


def _display_name(user: User) -> str:
    return (user.full_name or user.team_name or "").strip()


class SupportService:
    # ── Player side ───────────────────────────────────────────────────────────

    async def create_ticket(
        self, user: User, subject: str, message: str
    ) -> TicketDetailResponse:
        now = _utcnow()
        ticket = SupportTicket(
            user_id=user.id,
            user_email=user.email,
            user_name=_display_name(user),
            subject=subject.strip(),
            status="open",
            messages=[
                TicketMessage(
                    body=message.strip(),
                    author_is_admin=False,
                    author_name=_display_name(user),
                    sent_at=now,
                )
            ],
            last_activity_at=now,
        )
        await ticket.insert()
        return _to_detail(ticket)

    async def list_my_tickets(self, user: User) -> list[TicketSummaryResponse]:
        tickets = (
            await SupportTicket.find(SupportTicket.user_id == user.id)
            .sort(-SupportTicket.last_activity_at)
            .to_list()
        )
        return [_to_summary(t) for t in tickets]

    async def get_my_ticket(
        self, user: User, ticket_id: PydanticObjectId
    ) -> TicketDetailResponse:
        ticket = await self._get_owned(user, ticket_id)
        return _to_detail(ticket)

    async def reply_as_user(
        self, user: User, ticket_id: PydanticObjectId, message: str
    ) -> TicketDetailResponse:
        ticket = await self._get_owned(user, ticket_id)
        return await self._append(
            ticket,
            body=message,
            author_is_admin=False,
            author_name=_display_name(user),
            # The player answering a resolved ticket reopens it — otherwise a
            # premature "resolved" would bury the thread with nobody notified.
            new_status="open",
        )

    async def _get_owned(
        self, user: User, ticket_id: PydanticObjectId
    ) -> SupportTicket:
        ticket = await SupportTicket.get(ticket_id)
        # Same error either way: a stranger must not be able to tell an
        # id that exists from one that does not.
        if not ticket or ticket.user_id != user.id:
            raise NotFoundException("Ticket not found")
        return ticket

    # ── Admin side ────────────────────────────────────────────────────────────

    async def list_tickets(
        self,
        status: TicketStatus | None = None,
        search: str | None = None,
        page: int = 1,
        size: int = 20,
    ) -> TicketListResponse:
        query: dict = {}
        if status:
            query["status"] = status
        if search:
            escaped = {"$regex": search.strip(), "$options": "i"}
            query["$or"] = [
                {"subject": escaped},
                {"user_email": escaped},
                {"user_name": escaped},
            ]

        total = await SupportTicket.find(query).count()
        tickets = (
            await SupportTicket.find(query)
            .sort(-SupportTicket.last_activity_at)
            .skip((page - 1) * size)
            .limit(size)
            .to_list()
        )
        return TicketListResponse(
            total=total,
            page=page,
            size=size,
            items=[_to_summary(t) for t in tickets],
        )

    async def get_ticket(self, ticket_id: PydanticObjectId) -> TicketDetailResponse:
        ticket = await SupportTicket.get(ticket_id)
        if not ticket:
            raise NotFoundException("Ticket not found")
        return _to_detail(ticket)

    async def reply_as_admin(
        self, admin: User, ticket_id: PydanticObjectId, message: str
    ) -> TicketDetailResponse:
        ticket = await SupportTicket.get(ticket_id)
        if not ticket:
            raise NotFoundException("Ticket not found")
        return await self._append(
            ticket,
            body=message,
            author_is_admin=True,
            author_name=_display_name(admin) or "Support",
            # An admin reply hands the ticket back to the player. A resolved
            # or closed ticket keeps its status: replying to wrap something up
            # should not drag it back into the queue.
            new_status="pending" if ticket.status in ("open", "pending") else None,
        )

    async def set_status(
        self, ticket_id: PydanticObjectId, status: TicketStatus
    ) -> TicketDetailResponse:
        ticket = await SupportTicket.get(ticket_id)
        if not ticket:
            raise NotFoundException("Ticket not found")
        await ticket.save_updated(status=status)
        return _to_detail(ticket)

    async def counters(self) -> TicketCountersResponse:
        counts = await SupportTicket.aggregate(
            [{"$group": {"_id": "$status", "n": {"$sum": 1}}}]
        ).to_list()
        by_status = {row["_id"]: row["n"] for row in counts}

        # Counted in Python rather than in the pipeline: "awaiting admin"
        # depends on the last element of the embedded list, which is the one
        # thing the group stage above cannot see.
        live = await SupportTicket.find(
            {"status": {"$ne": "closed"}}
        ).to_list()

        return TicketCountersResponse(
            open=by_status.get("open", 0),
            pending=by_status.get("pending", 0),
            resolved=by_status.get("resolved", 0),
            closed=by_status.get("closed", 0),
            awaiting_admin=sum(1 for t in live if _awaiting_admin(t)),
        )

    # ── Shared ────────────────────────────────────────────────────────────────

    async def _append(
        self,
        ticket: SupportTicket,
        *,
        body: str,
        author_is_admin: bool,
        author_name: str,
        new_status: TicketStatus | None,
    ) -> TicketDetailResponse:
        if ticket.status == "closed":
            raise BadRequestException(
                "This ticket is closed. Please open a new one."
            )

        now = _utcnow()
        ticket.messages.append(
            TicketMessage(
                body=body.strip(),
                author_is_admin=author_is_admin,
                author_name=author_name,
                sent_at=now,
            )
        )
        updates: dict = {"messages": ticket.messages, "last_activity_at": now}
        if new_status:
            updates["status"] = new_status
        await ticket.save_updated(**updates)
        return _to_detail(ticket)


def get_support_service() -> SupportService:
    return SupportService()

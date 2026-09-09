"""
Admin (dashboard) side of the support inbox: read every ticket, reply, and
move it through its statuses. Mounted at /api to match the dashboard's base
URL.
"""
from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query

from app.modules.auth.dependencies import get_current_superuser
from app.modules.support.model import TICKET_STATUSES, TicketStatus
from app.modules.support.schema import (
    TicketCountersResponse,
    TicketDetailResponse,
    TicketListResponse,
    TicketReplyRequest,
    TicketStatusUpdateRequest,
)
from app.modules.support.service import SupportService, get_support_service
from app.modules.users.model import User

router = APIRouter(
    prefix="/admin/support/tickets",
    tags=["Admin: Support Center"],
    dependencies=[Depends(get_current_superuser)],
)


@router.get(
    "/",
    response_model=TicketListResponse,
    summary="List support tickets (newest activity first)",
)
async def list_tickets(
    status: TicketStatus | None = Query(
        None, description=f"Filter by status: {', '.join(TICKET_STATUSES)}"
    ),
    search: str | None = Query(None, description="Match subject, email or name"),
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    service: SupportService = Depends(get_support_service),
) -> TicketListResponse:
    return await service.list_tickets(status=status, search=search, page=page, size=size)


@router.get(
    "/counters/",
    response_model=TicketCountersResponse,
    summary="Ticket counts per status, plus how many await a reply",
)
async def ticket_counters(
    service: SupportService = Depends(get_support_service),
) -> TicketCountersResponse:
    return await service.counters()


@router.get(
    "/{ticket_id}/",
    response_model=TicketDetailResponse,
    summary="Read one ticket with its full conversation",
)
async def get_ticket(
    ticket_id: PydanticObjectId,
    service: SupportService = Depends(get_support_service),
) -> TicketDetailResponse:
    return await service.get_ticket(ticket_id)


@router.post(
    "/{ticket_id}/reply/",
    response_model=TicketDetailResponse,
    summary="Reply to a ticket (moves an open ticket to 'pending')",
)
async def reply_to_ticket(
    ticket_id: PydanticObjectId,
    payload: TicketReplyRequest,
    current_user: User = Depends(get_current_superuser),
    service: SupportService = Depends(get_support_service),
) -> TicketDetailResponse:
    return await service.reply_as_admin(current_user, ticket_id, payload.message)


@router.patch(
    "/{ticket_id}/status/",
    response_model=TicketDetailResponse,
    summary="Change a ticket's status",
)
async def set_ticket_status(
    ticket_id: PydanticObjectId,
    payload: TicketStatusUpdateRequest,
    service: SupportService = Depends(get_support_service),
) -> TicketDetailResponse:
    return await service.set_status(ticket_id, payload.status)

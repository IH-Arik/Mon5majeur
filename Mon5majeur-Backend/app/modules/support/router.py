"""
Player-facing support tickets (Flutter: Settings → Support).

Mounted at /api alongside the other Flutter-compat routers. Every route is
scoped to the caller's own tickets — there is no way to reach someone else's
thread from here.
"""
from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_current_user
from app.modules.support.schema import (
    TicketCreateRequest,
    TicketDetailResponse,
    TicketReplyRequest,
    TicketSummaryResponse,
)
from app.modules.support.service import SupportService, get_support_service
from app.modules.users.model import User

router = APIRouter(prefix="/support/tickets", tags=["Support (Flutter compat)"])


@router.get(
    "/",
    response_model=list[TicketSummaryResponse],
    summary="My support tickets (Flutter: SupportScreen list)",
)
async def my_tickets(
    current_user: User = Depends(get_current_user),
    service: SupportService = Depends(get_support_service),
) -> list[TicketSummaryResponse]:
    return await service.list_my_tickets(current_user)


@router.post(
    "/",
    response_model=TicketDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Open a new support ticket",
)
async def create_ticket(
    payload: TicketCreateRequest,
    current_user: User = Depends(get_current_user),
    service: SupportService = Depends(get_support_service),
) -> TicketDetailResponse:
    return await service.create_ticket(current_user, payload.subject, payload.message)


@router.get(
    "/{ticket_id}/",
    response_model=TicketDetailResponse,
    summary="Read one of my tickets with its conversation",
)
async def get_my_ticket(
    ticket_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: SupportService = Depends(get_support_service),
) -> TicketDetailResponse:
    return await service.get_my_ticket(current_user, ticket_id)


@router.post(
    "/{ticket_id}/reply/",
    response_model=TicketDetailResponse,
    summary="Reply on my ticket (reopens it if it was marked resolved)",
)
async def reply_to_my_ticket(
    ticket_id: PydanticObjectId,
    payload: TicketReplyRequest,
    current_user: User = Depends(get_current_user),
    service: SupportService = Depends(get_support_service),
) -> TicketDetailResponse:
    return await service.reply_as_user(current_user, ticket_id, payload.message)

import uuid

from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_current_user
from app.modules.notifications.dependencies import get_notification_service
from app.modules.notifications.model import Notification
from app.modules.notifications.schema import NotificationResponse
from app.modules.notifications.service import NotificationService
from app.modules.users.model import User
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=Page[NotificationResponse])
async def list_my_notifications(
    params: PaginationParams = Depends(),
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> Page[Notification]:
    return await service.list_for_user(current_user.id, params)


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def mark_notification_read(
    notification_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> Notification:
    return await service.mark_read(notification_id, current_user.id)


@router.patch("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_notifications_read(
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> None:
    await service.mark_all_read(current_user.id)

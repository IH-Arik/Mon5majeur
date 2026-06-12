import uuid
from typing import Literal

from app.shared.base_schema import BaseResponseSchema, BaseSchema


class NotificationCreate(BaseSchema):
    recipient_id: uuid.UUID
    title: str
    body: str
    notification_type: Literal["info", "success", "warning", "error"] = "info"
    action_url: str | None = None


class NotificationResponse(BaseResponseSchema):
    recipient_id: uuid.UUID
    title: str
    body: str
    is_read: bool
    notification_type: str
    action_url: str | None

from beanie import Link, PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class Notification(BaseDocument):
    recipient_id: PydanticObjectId
    title: str
    body: str
    is_read: bool = False
    notification_type: str = "info"
    action_url: str | None = None

    class Settings:
        name = "notifications"
        indexes = [
            IndexModel([("recipient_id", ASCENDING)]),
            IndexModel([("recipient_id", ASCENDING), ("is_read", ASCENDING)]),
        ]

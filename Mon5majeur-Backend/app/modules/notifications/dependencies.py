from app.modules.notifications.repository import NotificationRepository
from app.modules.notifications.service import NotificationService


def get_notification_service() -> NotificationService:
    return NotificationService(NotificationRepository())

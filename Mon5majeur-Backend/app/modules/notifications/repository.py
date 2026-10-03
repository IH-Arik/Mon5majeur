from beanie import PydanticObjectId

from app.modules.notifications.model import Notification
from app.shared.base_repository import BaseRepository


class NotificationRepository(BaseRepository[Notification]):
    def __init__(self) -> None:
        super().__init__(Notification)

    async def get_for_user(self, user_id: PydanticObjectId, offset: int, limit: int) -> tuple[list[Notification], int]:
        query = Notification.find(Notification.recipient_id == user_id)
        total = await query.count()
        # Most recent first. There was no sort at all, so the list came back
        # in insertion order: oldest on top, and the first page was the
        # oldest notifications (QA 30/09 #8 #2). `id` breaks created_at ties.
        items = await (
            query.sort(-Notification.created_at, -Notification.id)
            .skip(offset)
            .limit(limit)
            .to_list()
        )
        return items, total

    async def delete_all(self, user_id: PydanticObjectId) -> None:
        await Notification.find(Notification.recipient_id == user_id).delete()

    async def mark_all_read(self, user_id: PydanticObjectId) -> None:
        await Notification.find(
            Notification.recipient_id == user_id,
            Notification.is_read == False,
        ).update({"$set": {"is_read": True}})

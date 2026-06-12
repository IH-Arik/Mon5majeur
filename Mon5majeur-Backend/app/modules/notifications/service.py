from beanie import PydanticObjectId

from app.exceptions.errors import NotFoundException
from app.modules.notifications.model import Notification
from app.modules.notifications.repository import NotificationRepository
from app.modules.notifications.schema import NotificationCreate
from app.shared.pagination import Page, PaginationParams


class NotificationService:
    def __init__(self, repo: NotificationRepository | None = None) -> None:
        self.repo = repo or NotificationRepository()

    async def create(self, payload: NotificationCreate) -> Notification:
        return await self.repo.create(**payload.model_dump())

    async def list_for_user(self, user_id: PydanticObjectId, params: PaginationParams) -> Page[Notification]:
        items, total = await self.repo.get_for_user(user_id, params.offset, params.limit)
        return Page.create(items, total, params)

    async def mark_read(self, notification_id: PydanticObjectId, user_id: PydanticObjectId) -> Notification:
        n = await self.repo.get(notification_id)
        if not n or n.recipient_id != user_id:
            raise NotFoundException("Notification not found")
        return await self.repo.update(n, is_read=True)

    async def mark_all_read(self, user_id: PydanticObjectId) -> None:
        await self.repo.mark_all_read(user_id)

    async def send_push_to_user(
        self,
        user_id: PydanticObjectId,
        title: str,
        body: str,
        data: dict | None = None,
        notification_type: str = "info",
    ) -> None:
        """
        1. Persist a Notification document (in-app).
        2. Send FCM push if user has a registered token.
        """
        from app.modules.users.model import User
        from app.modules.notifications.fcm import send_push

        # Save in-app notification
        await Notification(
            recipient_id=user_id,
            title=title,
            body=body,
            notification_type=notification_type,
        ).insert()

        # Send push
        user = await User.get(user_id)
        if user and user.fcm_token and user.push_notifications_enabled:
            notification_types = user.notification_types or []
            if data and data.get("type") in notification_types or not notification_types:
                await send_push(user.fcm_token, title, body, data)

    async def notify_player_out(self, player_name: str, reason: str) -> None:
        """Send OUT alert to all users who have this player in their active lineup."""
        from app.modules.lineups.model import LineupSlot
        from datetime import datetime, timezone

        today = datetime.now(timezone.utc).date()

        slots = await LineupSlot.find(
            LineupSlot.player_name == player_name,
            LineupSlot.nba_date == today,
            LineupSlot.score_finalized == False,  # noqa: E712
        ).to_list()

        notified: set = set()
        for slot in slots:
            if slot.user_id in notified:
                continue
            await self.send_push_to_user(
                user_id=slot.user_id,
                title=f"{player_name} is OUT",
                body=f"Reason: {reason}. Update your lineup before tip-off.",
                data={"type": "player_out", "player_name": player_name},
                notification_type="player_out",
            )
            notified.add(slot.user_id)

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

    async def notify_player_out(
        self,
        player_id: PydanticObjectId,
        player_name: str,
        reason: str,
        nba_date=None,
    ) -> None:
        """Alert every user holding this player in a not-yet-locked lineup
        (spec §4.7 point 3 / §4.8 notification 1).

        Reads FlutterPlayerSelection, which is where the team builder
        actually writes; LineupSlot is only populated by the /api/v1/lineups
        path the app does not use, so querying it found nobody. Both stores
        are checked so neither path is missed.

        One push per user even if the player sits in several of their
        leagues — §4.8 forbids bursts.
        """
        from datetime import datetime, timezone

        from app.modules.lineups.compat_model import FlutterPlayerSelection
        from app.modules.lineups.model import LineupSlot

        night = nba_date or datetime.now(timezone.utc).date()
        recipients: list = []

        # selected_players / sixth_man_player hold the raw player JSON, so the
        # id is matched inside the embedded documents.
        pid = str(player_id)
        selections = await FlutterPlayerSelection.find(
            {
                "nba_date": datetime.combine(night, datetime.min.time()),
                "$or": [
                    {"selected_players.id": {"$in": [pid, player_id]}},
                    {"sixth_man_player.id": {"$in": [pid, player_id]}},
                ],
            }
        ).to_list()
        recipients.extend(s.user_id for s in selections)

        slots = await LineupSlot.find(
            LineupSlot.player_id == player_id,
            LineupSlot.nba_date == night,
            LineupSlot.score_finalized == False,  # noqa: E712
        ).to_list()
        recipients.extend(s.user_id for s in slots)

        notified: set = set()
        for user_id in recipients:
            if user_id in notified:
                continue
            notified.add(user_id)
            await self.send_push_to_user(
                user_id=user_id,
                title=f"{player_name} is OUT",
                body=f"Reason: {reason}. Update your lineup before tip-off.",
                data={"type": "player_out", "player_name": player_name},
                notification_type="player_out",
            )

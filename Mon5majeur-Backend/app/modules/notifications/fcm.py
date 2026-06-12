"""
FCM push notification sender.
Uses firebase-admin SDK. Credentials loaded once at first call.
"""
from __future__ import annotations

import logging

logger = logging.getLogger(__name__)

_fcm_initialized = False


def _init_fcm() -> bool:
    global _fcm_initialized
    if _fcm_initialized:
        return True

    try:
        import firebase_admin
        from firebase_admin import credentials

        from app.core.config import settings

        if not settings.FCM_CREDENTIALS_PATH:
            logger.warning("FCM_CREDENTIALS_PATH not set — push notifications disabled")
            return False

        cred = credentials.Certificate(settings.FCM_CREDENTIALS_PATH)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        _fcm_initialized = True
        return True
    except Exception as exc:
        logger.error("FCM init failed: %s", exc)
        return False


async def send_push(
    token: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    if not _init_fcm():
        return False

    try:
        from firebase_admin import messaging

        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
        )
        messaging.send(msg)
        return True
    except Exception as exc:
        logger.warning("FCM send failed (token=%s...): %s", token[:8], exc)
        return False


async def send_push_multicast(
    tokens: list[str],
    title: str,
    body: str,
    data: dict | None = None,
) -> int:
    """Send to multiple tokens. Returns success count."""
    if not tokens or not _init_fcm():
        return 0

    try:
        from firebase_admin import messaging

        msg = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            tokens=tokens,
        )
        response = messaging.send_each_for_multicast(msg)
        return response.success_count
    except Exception as exc:
        logger.warning("FCM multicast failed: %s", exc)
        return 0

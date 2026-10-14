import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from firebase_admin import exceptions, messaging

from app.modules.notifications import fcm


def _send(token="abcdef1234567890", side_effect=None, return_value="projects/x/messages/1"):
    with patch.object(fcm, "_init_fcm", return_value=True), patch.object(
        messaging, "send", side_effect=side_effect, return_value=return_value
    ):
        return asyncio.run(fcm.send_push(token, "t", "b"))


def test_successful_send_returns_the_message_id():
    result = _send()
    assert result.ok and result.code == "projects/x/messages/1"


def test_unregistered_token_is_reported_as_dead():
    err = messaging.UnregisteredError("gone", cause=None, http_response=None)
    result = _send(side_effect=err)
    assert not result.ok and result.dead_token and result.code == "UnregisteredError"


def test_other_failures_are_not_dead_tokens():
    err = exceptions.UnavailableError("later")
    result = _send(side_effect=err)
    assert not result.ok and not result.dead_token and result.code == "UnavailableError"


def test_failure_log_never_contains_the_full_token(caplog):
    token = "SECRETTOKEN-1234567890-abcdefghij"
    with caplog.at_level("WARNING"):
        _send(token=token, side_effect=exceptions.UnavailableError("later"))
    assert token not in caplog.text
    assert token[:6] in caplog.text


def test_without_credentials_nothing_is_sent():
    with patch.object(fcm, "_init_fcm", return_value=False):
        result = asyncio.run(fcm.send_push("tok", "t", "b"))
    assert not result.ok and result.code == "FCM_NOT_INITIALIZED"


def test_dead_token_is_removed_from_the_account():
    from app.modules.notifications import service as svc

    user = SimpleNamespace(
        fcm_token="tok", push_notifications_enabled=True, notification_types=[],
        language="en", save=AsyncMock(),
    )
    dead = fcm.PushResult(False, "UnregisteredError", dead_token=True)

    class FakeNotification:
        def __init__(self, **kw): pass
        async def insert(self): pass

    with patch("app.modules.users.model.User") as users, patch.object(
        svc, "Notification", FakeNotification
    ), patch("app.modules.notifications.fcm.send_push", AsyncMock(return_value=dead)):
        users.get = AsyncMock(return_value=user)
        asyncio.run(svc.NotificationService().send_push_to_user("u1", "T", "B"))
    assert user.fcm_token is None
    user.save.assert_awaited()

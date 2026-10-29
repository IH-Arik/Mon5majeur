import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock

from app.modules.users.router import update_fcm_token


def test_registering_a_token_turns_push_on():
    user = SimpleNamespace(fcm_token=None, push_notifications_enabled=False, save=AsyncMock())
    asyncio.run(update_fcm_token("tok123", current_user=user))
    assert user.fcm_token == "tok123"
    assert user.push_notifications_enabled is True

import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.modules.users import router
from app.modules.users.router import delete_fcm_token, update_fcm_token


@pytest.fixture
def other_accounts(monkeypatch):
    """Stands in for the Mongo query that clears the token elsewhere."""
    query = MagicMock()
    query.update_many = AsyncMock()
    find = MagicMock(return_value=query)
    monkeypatch.setattr(router.User, "find", find, raising=False)
    return find, query


def _user(**kw):
    return SimpleNamespace(
        id="me", fcm_token=None, push_notifications_enabled=False, save=AsyncMock(), **kw
    )


def test_registering_a_token_turns_push_on(other_accounts):
    user = _user()
    asyncio.run(update_fcm_token("tok123", current_user=user))
    assert user.fcm_token == "tok123"
    assert user.push_notifications_enabled is True


def test_enable_false_keeps_push_off(other_accounts):
    user = _user()
    asyncio.run(update_fcm_token("tok123", enable=False, current_user=user))
    assert user.fcm_token == "tok123"
    assert user.push_notifications_enabled is False


def test_token_is_taken_away_from_every_other_account(other_accounts):
    find, query = other_accounts
    asyncio.run(update_fcm_token("tok123", current_user=_user()))
    find.assert_called_once_with({"fcm_token": "tok123", "_id": {"$ne": "me"}})
    query.update_many.assert_awaited_once_with({"$set": {"fcm_token": None}})


def test_delete_clears_token_but_keeps_the_preference():
    user = SimpleNamespace(fcm_token="tok123", push_notifications_enabled=True, save=AsyncMock())
    asyncio.run(delete_fcm_token(current_user=user))
    assert user.fcm_token is None
    assert user.push_notifications_enabled is True
    user.save.assert_awaited_once()


def test_delete_without_token_is_a_no_op():
    user = SimpleNamespace(fcm_token=None, push_notifications_enabled=True, save=AsyncMock())
    asyncio.run(delete_fcm_token(current_user=user))
    user.save.assert_not_awaited()

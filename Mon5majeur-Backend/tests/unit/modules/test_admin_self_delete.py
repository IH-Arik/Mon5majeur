import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.exceptions.errors import ForbiddenException
from app.modules.users.service import UserService


def _svc():
    s = UserService.__new__(UserService)
    s.delete_user = AsyncMock()
    return s


def test_an_admin_cannot_delete_his_own_account_from_the_app():
    s = _svc()
    with pytest.raises(ForbiddenException):
        asyncio.run(s.delete_own_account(SimpleNamespace(id="A", is_superuser=True)))
    s.delete_user.assert_not_awaited()


def test_a_player_still_can():
    s = _svc()
    asyncio.run(s.delete_own_account(SimpleNamespace(id="P", is_superuser=False)))
    s.delete_user.assert_awaited_once_with("P")

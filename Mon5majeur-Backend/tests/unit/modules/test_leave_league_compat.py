import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.exceptions.errors import BadRequestException, NotFoundException
from app.modules.leagues import service as svc_mod
from app.modules.leagues.service import LeagueService


def _service(league, membership=object()):
    league_repo = SimpleNamespace(get=AsyncMock(return_value=league))
    membership_obj = SimpleNamespace(delete=AsyncMock()) if membership else None
    membership_repo = SimpleNamespace(get_membership=AsyncMock(return_value=membership_obj))
    s = LeagueService(league_repo, membership_repo, None)
    s._release_seat = AsyncMock()
    return s, membership_obj


def _league(status="waiting", admin="ADMIN"):
    return SimpleNamespace(id="L", auto_id=12, status=status, admin_id=admin, type="public")


def _leave(league, user, membership=True):
    s, m = _service(league, membership)
    found = MagicMock()
    found.find_one = AsyncMock(return_value=league)
    emit = AsyncMock()
    with patch.object(svc_mod, "League", found), \
            patch("app.modules.leagues.ws_router.emit_team_left", emit):
        out = asyncio.run(s.leave_league_compat(12, user, "public"))
    return out, m, emit


USER = SimpleNamespace(id="U", auto_id=44, team_name="Rob1")


def test_a_member_leaves_a_waiting_league_by_its_integer_id():
    out, m, emit = _leave(_league(), USER)
    m.delete.assert_awaited_once()
    assert emit.await_args.kwargs["team_id"] == 44   # others see the departure


def test_a_started_league_cannot_be_left():
    with pytest.raises(BadRequestException):
        _leave(_league(status="regular_season"), USER)


def test_the_creator_cannot_leave():
    with pytest.raises(BadRequestException):
        _leave(_league(admin="U"), USER)


def test_unknown_league():
    s, _ = _service(None)
    found = MagicMock()
    found.find_one = AsyncMock(return_value=None)
    with patch.object(svc_mod, "League", found):
        with pytest.raises(NotFoundException):
            asyncio.run(s.leave_league_compat(99, USER, "private"))

"""Arik QA item 14: only a signed-in player may listen to a league's events."""
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

import pytest

from app.modules.leagues import ws_router

app = FastAPI()
app.include_router(ws_router.router)
USER = SimpleNamespace(id="U", is_superuser=False, is_active=True)


def _connect(path, user, allowed):
    with patch.object(ws_router, "ws_user", AsyncMock(return_value=user)), \
            patch.object(ws_router, "may_listen", AsyncMock(return_value=allowed)):
        with TestClient(app).websocket_connect(path) as ws:
            ws.send_text("ping")
            return True


def test_no_token_is_refused():
    with pytest.raises(WebSocketDisconnect) as err:
        _connect("/ws/private-leagues/5/", None, True)
    assert err.value.code == ws_router.WS_UNAUTHORIZED


def test_a_non_member_of_a_private_league_is_refused():
    with pytest.raises(WebSocketDisconnect) as err:
        _connect("/ws/private-leagues/5/?token=t", USER, False)
    assert err.value.code == ws_router.WS_FORBIDDEN


def test_a_member_is_let_in():
    assert _connect("/ws/private-leagues/5/?token=t", USER, True)


def test_an_invalid_token_gives_no_user():
    import asyncio
    assert asyncio.run(ws_router.ws_user("not-a-jwt")) is None
    assert asyncio.run(ws_router.ws_user(None)) is None


def _may(league, member):
    import asyncio
    leagues = SimpleNamespace(find_one=AsyncMock(return_value=league), auto_id=None)
    members = SimpleNamespace(find_one=AsyncMock(return_value=object() if member else None),
                              league_id=None, user_id=None)
    with patch("app.modules.leagues.model.League", leagues), \
            patch("app.modules.leagues.model.LeagueMembership", members):
        return asyncio.run(ws_router.may_listen(USER, 5, "private"))


def test_a_public_league_opened_through_the_private_path_stays_open():
    assert _may(SimpleNamespace(id="L", type="public"), member=False)


def test_a_private_league_needs_membership():
    assert not _may(SimpleNamespace(id="L", type="private"), member=False)
    assert _may(SimpleNamespace(id="L", type="private"), member=True)


def test_an_unknown_league_is_refused():
    assert not _may(None, member=True)

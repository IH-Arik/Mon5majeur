import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.modules.leagues.service import LeagueService


def _league(status):
    return SimpleNamespace(
        id="L1", auto_id=7, name="Test", description="", logo="", budget=100,
        max_size=4, invite_code=None, admin_id=None, current_match_day=9,
        current_week=1, status=status, created_at=datetime.now(timezone.utc),
        started_at=None,
    )


def _service():
    repo = SimpleNamespace(get_league_members=AsyncMock(return_value=[]))
    return LeagueService(None, repo, None)


@pytest.mark.parametrize(
    "status", ["waiting", "regular_season", "playoffs", "completed", "cancelled"]
)
def test_my_leagues_exposes_the_league_status(status):
    out = asyncio.run(_service()._to_compat_response(_league(status), []))
    assert out.status == status


def test_league_without_status_returns_null():
    out = asyncio.run(_service()._to_compat_response(_league(None), []))
    assert out.status is None

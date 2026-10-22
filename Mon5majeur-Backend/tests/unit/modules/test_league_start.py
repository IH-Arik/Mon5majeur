"""Arik QA item 6: starting a league is all or nothing, once, with 4+ teams."""
import asyncio
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.exceptions.errors import BadRequestException
from app.modules.leagues import engine


@pytest.mark.parametrize("n", [0, 2, 3, 5, 7])
def test_fewer_than_4_or_an_odd_number_cannot_start(n):
    with pytest.raises(BadRequestException):
        engine.check_team_count(n)


@pytest.mark.parametrize("n", [4, 6, 8, 10])
def test_4_6_8_10_can_start(n):
    engine.check_team_count(n)


def test_a_second_start_at_the_same_time_is_refused():
    with patch("app.cron.lock.try_acquire", AsyncMock(return_value=False)):
        with pytest.raises(BadRequestException, match="already being started"):
            asyncio.run(engine.start_league("L", date(2026, 10, 22)))


def test_a_failed_start_removes_the_matches_already_written():
    league = SimpleNamespace(status="waiting", save=AsyncMock(side_effect=RuntimeError("db")))
    leagues = MagicMock()
    leagues.get = AsyncMock(return_value=league)
    members = MagicMock()

    class _Q:
        async def to_list(self):
            return [SimpleNamespace(user_id=f"u{i}") for i in range(4)]
    members.find = MagicMock(return_value=_Q())
    members.league_id = MagicMock()
    deleted = AsyncMock()
    matches = MagicMock()
    matches.return_value.insert = AsyncMock()
    matches.find = MagicMock(return_value=SimpleNamespace(delete=deleted))
    matches.league_id = MagicMock()
    with patch.object(engine, "League", leagues), \
            patch.object(engine, "LeagueMembership", members), \
            patch.object(engine, "LeagueMatch", matches), \
            patch("app.cron.lock.try_acquire", AsyncMock(return_value=True)), \
            patch("app.cron.lock.release", AsyncMock()) as release:
        with pytest.raises(RuntimeError):
            asyncio.run(engine.start_league("L", date(2026, 10, 22)))
    deleted.assert_awaited_once()
    release.assert_awaited_once()

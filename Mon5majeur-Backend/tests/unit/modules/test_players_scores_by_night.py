"""GET /api/players-today-scores/ for a given night (top 1-2-3 of any night)."""
import asyncio
from datetime import date, datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException

from app.modules.leagues.schema import PlayerTodayScoreItem
from app.modules.players import compat_router
from app.modules.players.compat_router import players_today_scores

USER = SimpleNamespace()
NIGHT = date(2026, 11, 2)


def _call(nba_date=None):
    return asyncio.run(players_today_scores(nba_date=nba_date, _=USER))


def _item(pid, score):
    return PlayerTodayScoreItem(id=pid, name=pid, score=score)


@pytest.fixture
def scores(monkeypatch):
    """The ranking itself (database) is replaced by a fixed list."""
    fake = AsyncMock(return_value=[_item("a", 50), _item("b", 40)])
    monkeypatch.setattr(compat_router, "_night_player_scores", fake)
    return fake


def test_a_published_night_is_ranked_and_echoed(scores):
    with patch("app.modules.players.night_publication.published_marks",
               AsyncMock(return_value={NIGHT})), \
         patch.object(compat_router, "datetime") as dt:
        dt.now.return_value = datetime(2026, 11, 3, 12, 0, tzinfo=timezone.utc)
        out = _call("2026-11-02")
    assert out.nba_date == "2026-11-02"
    assert [i.id for i in out.results] == ["a", "b"]
    scores.assert_awaited_once_with(NIGHT)


def test_an_unpublished_night_leaks_nothing(scores):
    # 08:00 Paris on 3 Nov: the night of 2 Nov is not published yet.
    with patch("app.modules.players.night_publication.published_marks",
               AsyncMock(return_value=set())), \
         patch.object(compat_router, "datetime") as dt:
        dt.now.return_value = datetime(2026, 11, 3, 7, 0, tzinfo=timezone.utc)
        out = _call("2026-11-02")
    assert out.nba_date == "2026-11-02"
    assert out.results == []
    scores.assert_not_awaited()


def test_a_future_night_is_empty(scores):
    with patch("app.modules.players.night_publication.published_marks",
               AsyncMock(return_value=set())), \
         patch.object(compat_router, "datetime") as dt:
        dt.now.return_value = datetime(2026, 11, 3, 12, 0, tzinfo=timezone.utc)
        out = _call("2026-12-25")
    assert out.results == []
    scores.assert_not_awaited()


def test_a_bad_date_is_refused(scores):
    with pytest.raises(HTTPException) as err:
        _call("not-a-date")
    assert err.value.status_code == 422


def test_without_a_date_the_last_published_night_is_used(scores):
    with patch("app.modules.players.nba_night.published_night",
               AsyncMock(return_value=NIGHT)):
        out = _call(None)
    assert out.nba_date == "2026-11-02"
    scores.assert_awaited_once_with(NIGHT)

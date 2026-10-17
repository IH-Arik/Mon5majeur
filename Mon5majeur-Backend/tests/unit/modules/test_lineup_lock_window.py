"""QA #13 addendum: everything stays locked until the 09:00 publication."""
import asyncio
from datetime import date, datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch
from zoneinfo import ZoneInfo

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.exceptions.errors import LineupLockedException
from app.exceptions.handlers import register_exception_handlers
from app.modules.leagues import lineup_state as ls
from app.modules.players import nba_night

PARIS = ZoneInfo("Europe/Paris")
SUMMER_NIGHT = date(2026, 7, 10)    # published 2026-07-11 09:00 CEST
WINTER_NIGHT = date(2026, 12, 10)   # published 2026-12-11 09:00 CET


def _paris(night: date, day_offset: int, hour: int, minute: int) -> datetime:
    d = date.fromordinal(night.toordinal() + day_offset)
    return datetime(d.year, d.month, d.day, hour, minute, tzinfo=PARIS).astimezone(timezone.utc)


@pytest.mark.parametrize("night", [SUMMER_NIGHT, WINTER_NIGHT], ids=["summer", "winter"])
@pytest.mark.parametrize(
    "hour, minute",
    [(0, 30), (2, 0), (5, 0), (8, 59)],
    ids=["00:30", "02:00", "05:00", "08:59"],
)
def test_the_night_is_never_published_before_09_00_paris(night, hour, minute):
    now = _paris(night, 1, hour, minute)
    # Not even when the close already marked it: the cutoff is the earliest.
    assert not nba_night.is_published(night, now, marked=True)
    assert not nba_night.is_published(night, now, marked=False)


@pytest.mark.parametrize("night", [SUMMER_NIGHT, WINTER_NIGHT], ids=["summer", "winter"])
def test_at_09_05_it_opens_once_the_close_marked_it(night):
    assert nba_night.is_published(night, _paris(night, 1, 9, 5), marked=True)


@pytest.mark.parametrize("night", [SUMMER_NIGHT, WINTER_NIGHT], ids=["summer", "winter"])
def test_a_late_publication_keeps_everything_locked(night):
    # 09:05 and 11:59: the close has not reported, still locked.
    assert not nba_night.is_published(night, _paris(night, 1, 9, 5), marked=False)
    assert not nba_night.is_published(night, _paris(night, 1, 11, 59), marked=False)


@pytest.mark.parametrize("night", [SUMMER_NIGHT, WINTER_NIGHT], ids=["summer", "winter"])
def test_a_close_that_never_reports_does_not_lock_forever(night):
    assert nba_night.is_published(night, _paris(night, 1, 12, 1), marked=False)


def test_the_flip_is_at_09_00_paris_not_at_utc_midnight():
    # 02:00 Paris in summer is exactly 00:00 UTC, the old flip.
    now = _paris(SUMMER_NIGHT, 1, 2, 0)
    assert now.hour == 0 and now.minute == 0
    assert not nba_night.is_published(SUMMER_NIGHT, now, marked=False)


class _Col:
    def __ge__(self, other):
        return True

    def __pos__(self):
        return self


class _FakeGames:
    nba_date = _Col()

    def __init__(self, nights):
        self._rows = [SimpleNamespace(nba_date=n) for n in nights]

    def find(self, *a, **k):
        return self

    def sort(self, *a, **k):
        return self

    async def to_list(self):
        return self._rows


def _composing(now, nights, marks):
    fake = type("G", (_FakeGames,), {})(nights)
    with patch.object(nba_night, "NBAGame", fake), patch(
        "app.modules.players.night_publication.published_marks",
        AsyncMock(return_value=set(marks)),
    ):
        return asyncio.run(nba_night.composing_night(now))


def test_at_02_40_the_current_night_is_still_the_one_being_composed():
    nights = [date(2026, 10, 13), date(2026, 10, 14)]
    now = _paris(date(2026, 10, 13), 1, 2, 40)
    assert _composing(now, nights, marks=[]) == date(2026, 10, 13)


def test_at_09_05_with_the_close_done_the_next_night_opens():
    nights = [date(2026, 10, 13), date(2026, 10, 14)]
    now = _paris(date(2026, 10, 13), 1, 9, 5)
    assert _composing(now, nights, marks=[date(2026, 10, 13)]) == date(2026, 10, 14)


def test_at_09_05_with_a_late_close_the_night_stays_the_same():
    nights = [date(2026, 10, 13), date(2026, 10, 14)]
    now = _paris(date(2026, 10, 13), 1, 9, 5)
    assert _composing(now, nights, marks=[]) == date(2026, 10, 13)


def _league(day=9, type_="private"):
    return SimpleNamespace(type=type_, current_match_day=day, auto_id=3)


def _ensure(state, league=None, match_day=None):
    info = ls.LineupState(state, 0 if state != ls.OPEN else 600, False)
    with patch.object(ls, "league_state", AsyncMock(return_value=info)), patch.object(
        ls, "reopens_at", AsyncMock(return_value="2026-10-14T07:00:00+00:00")
    ):
        return asyncio.run(ls.ensure_open(league or _league(), "U", match_day))


@pytest.mark.parametrize("state", [ls.LOCKED, ls.WAITING_RESULTS])
def test_composing_is_refused_while_locked(state):
    with pytest.raises(LineupLockedException) as err:
        _ensure(state)
    assert err.value.status_code == 403
    assert err.value.extra == {
        "code": "lineup_locked",
        "reopens_at": "2026-10-14T07:00:00+00:00",
    }


def test_composing_is_possible_when_open():
    assert _ensure(ls.OPEN, match_day=9).state == ls.OPEN


def test_a_player_with_no_game_is_not_blocked_by_the_lock():
    assert _ensure(ls.NOT_PLAYING).state == ls.NOT_PLAYING


def test_the_wrong_day_is_refused_even_when_the_night_is_open():
    with pytest.raises(LineupLockedException):
        _ensure(ls.OPEN, league=_league(day=9), match_day=10)


def test_the_global_league_has_no_match_day_to_get_wrong():
    assert _ensure(ls.OPEN, league=_league(type_="global"), match_day=999).state == ls.OPEN


def test_the_403_body_carries_the_code_and_reopens_at():
    app = FastAPI()
    register_exception_handlers(app)

    @app.post("/save")
    async def save():
        raise LineupLockedException("2026-10-14T07:00:00+00:00")

    r = TestClient(app).post("/save")
    assert r.status_code == 403
    body = r.json()
    assert body["code"] == "lineup_locked"
    assert body["reopens_at"] == "2026-10-14T07:00:00+00:00"
    assert body["status_code"] == 403 and body["detail"]

"""QA #10 18: every game of the night is followed, not only the first one."""
from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

from app.cron import jobs
from app.modules.players.nba_night import polling_nights


def test_two_dates_are_in_play_after_midnight_utc():
    # 00:30 UTC on the 8th = 02:30 Paris: games of the 7th are still on court
    now = datetime(2026, 10, 8, 0, 30, tzinfo=timezone.utc)
    assert polling_nights(now) == [date(2026, 10, 7), date(2026, 10, 8)]


def test_the_previous_night_is_polled_even_when_tomorrows_games_are_loaded(monkeypatch):
    """The schedule sync now loads the coming days, so the 8th already has
    games when the 7th is still being played; the job used to look at the 8th
    only and never polled the games tipping off at 02:00."""
    from app.modules.players import model as pm
    from app.modules.players import service as ps

    now = datetime.now(timezone.utc)
    yesterday, today = (now - timedelta(days=1)).date(), now.date()
    started = SimpleNamespace(status="live", tip_off_time=now - timedelta(hours=1), goalserve_id="a")
    not_started = SimpleNamespace(status="scheduled", tip_off_time=now + timedelta(hours=20), goalserve_id="b")
    by_date = {yesterday: [started], today: [not_started]}
    polled = []

    class _Field:
        def __init__(self, n):
            self.n = n

        def __eq__(self, other):
            return other

    class _NBAGame:
        nba_date = _Field("nba_date")

        @staticmethod
        def find(d):
            async def _list():
                return by_date.get(d, [])

            return SimpleNamespace(to_list=_list)

    async def _sync(self, night):
        polled.append(night)
        return 0

    async def _flip(night):
        return 0

    async def _final(self, gid):
        return 0

    import app.modules.leagues.engine as engine

    monkeypatch.setattr(pm, "NBAGame", _NBAGame)
    monkeypatch.setattr(ps.PlayerService, "sync_scores_for_date", _sync)
    monkeypatch.setattr(ps.PlayerService, "finalize_game_scores", _final)
    monkeypatch.setattr(engine, "sync_match_live_status", _flip)

    asyncio.run(jobs.sync_live_games_job())

    assert polled == [yesterday]   # the night in progress, not the idle next one

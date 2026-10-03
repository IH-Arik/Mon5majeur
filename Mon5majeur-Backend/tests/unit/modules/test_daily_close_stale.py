"""2026-10-03 production finding: daily_close broke on a stale June night
every day and never reached a real one."""
from __future__ import annotations

import asyncio
from datetime import date, datetime, timezone

import pytest

from app.cron import jobs
from app.modules.players.goalserve_client import GoalserveEmptyResponseError


def _setup(monkeypatch, *, pending, latest, unrecoverable):
    """Stub everything daily_close_job touches; record what it did."""
    import app.cron.lock as lock
    import app.modules.bonuses.service as bonus_service
    import app.modules.leagues.engine as engine
    import app.modules.leagues.global_score_service as gss
    import app.modules.lineups.service as lineup_service
    import app.modules.players.nba_night as nba_night
    import app.modules.players.repository as prepo
    import app.modules.players.service as pservice

    seen = {"closed": [], "released": [], "prices": 0}

    async def _acquire(*_a, **_k):
        return True

    async def _release(key):
        seen["released"].append(key)

    async def _prepare(night):
        if night in unrecoverable:
            raise GoalserveEmptyResponseError(f"night {night}: nothing")

    async def _close(night):
        seen["closed"].append(night)
        return {}

    async def _latest(_today):
        return latest

    async def _pending(_today):
        return pending

    async def _none(*_a, **_k):
        return 0

    class _Lineups:
        def __init__(self, *_a):
            pass

        fill_slot_scores_from_stats = staticmethod(_none)
        finalize_lineup_scores = staticmethod(_none)

    class _Players:
        def __init__(self, *_a):
            pass

        async def recompute_all_prices(self):
            seen["prices"] += 1
            return 0

    monkeypatch.setattr(lock, "try_acquire", _acquire)
    monkeypatch.setattr(lock, "release", _release)
    monkeypatch.setattr(engine, "run_daily_close", _close)
    monkeypatch.setattr(nba_night, "latest_finished_night", _latest)
    monkeypatch.setattr(jobs, "_nights_pending_close", _pending)
    monkeypatch.setattr(jobs, "_prepare_night_data", _prepare)
    monkeypatch.setattr(jobs, "_send_results_pushes", _none)
    monkeypatch.setattr(lineup_service, "LineupService", _Lineups)
    monkeypatch.setattr(bonus_service, "BonusService", lambda *a: None)
    monkeypatch.setattr(pservice, "PlayerService", _Players)
    monkeypatch.setattr(prepo, "PlayerRepository", lambda *a: None)
    monkeypatch.setattr(gss, "archive_daily_scores", _none)
    return seen


def _fake_today(monkeypatch, d):
    class _DT(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(d.year, d.month, d.day, 7, 0, tzinfo=timezone.utc)

    monkeypatch.setattr(jobs, "datetime", _DT)


def test_a_stale_unrecoverable_night_no_longer_blocks_a_real_one(monkeypatch):
    stale, real = date(2026, 6, 14), date(2026, 10, 4)
    seen = _setup(monkeypatch, pending=[stale, real], latest=real, unrecoverable={stale})
    _fake_today(monkeypatch, date(2026, 10, 5))

    asyncio.run(jobs.daily_close_job())

    assert seen["closed"] == [real]
    assert seen["prices"] == 1


def test_a_recent_unrecoverable_night_still_stops_later_ones(monkeypatch):
    recent, newer = date(2026, 10, 3), date(2026, 10, 4)
    seen = _setup(monkeypatch, pending=[recent, newer], latest=newer, unrecoverable={recent})
    _fake_today(monkeypatch, date(2026, 10, 5))

    asyncio.run(jobs.daily_close_job())

    assert seen["closed"] == []  # ordering protection kept for recent nights
    assert seen["prices"] == 0
    assert seen["released"], "a failed close must free the lock so it can be re-run"


def test_schedule_sync_covers_today_and_the_coming_week(monkeypatch):
    import app.modules.players.repository as prepo
    import app.modules.players.service as pservice

    asked = []

    class _Players:
        def __init__(self, *_a):
            pass

        async def sync_schedule(self, d):
            asked.append(d)
            return 0

    monkeypatch.setattr(pservice, "PlayerService", _Players)
    monkeypatch.setattr(prepo, "PlayerRepository", lambda *a: None)
    _fake_today(monkeypatch, date(2026, 10, 3))

    asyncio.run(jobs.sync_today_schedule_job())

    assert asked[0] == date(2026, 10, 3)
    assert asked[-1] == date(2026, 10, 10)
    assert len(asked) == 8

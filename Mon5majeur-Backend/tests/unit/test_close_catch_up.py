from datetime import datetime
from unittest.mock import MagicMock, patch
from zoneinfo import ZoneInfo

from app.cron import scheduler as sched


def _run(hour, minute):
    fake_now = datetime(2026, 10, 13, hour, minute, tzinfo=ZoneInfo("Europe/Paris"))
    scheduler = MagicMock()
    with patch.object(sched, "datetime") as dt:
        dt.now.return_value = fake_now
        sched._schedule_close_catch_up(scheduler, lambda: None)
    return scheduler


def test_restart_after_the_slot_schedules_a_catch_up():
    assert _run(9, 19).add_job.call_count == 1


def test_restart_before_the_slot_does_nothing():
    assert _run(8, 45).add_job.call_count == 0


def test_restart_long_after_the_window_does_nothing():
    assert _run(15, 0).add_job.call_count == 0

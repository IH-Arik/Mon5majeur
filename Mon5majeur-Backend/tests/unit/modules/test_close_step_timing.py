import logging

import pytest

from app.cron.jobs import _timed_step


def test_a_step_logs_its_start_end_and_duration(caplog):
    with caplog.at_level(logging.INFO, logger="app.cron.jobs"):
        with _timed_step("Global League archive", "2026-10-12"):
            pass
    text = caplog.text
    assert "'Global League archive' START" in text
    assert "'Global League archive' END" in text
    assert "2026-10-12" in text


def test_a_failing_step_still_logs_its_end_and_reraises(caplog):
    with caplog.at_level(logging.INFO, logger="app.cron.jobs"):
        with pytest.raises(RuntimeError):
            with _timed_step("player prices"):
                raise RuntimeError("boom")
    assert "'player prices' END" in caplog.text

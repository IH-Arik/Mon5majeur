"""QA #9 7.4 / 12.2: Live keeps the night until the 09:00 Paris publication."""
from __future__ import annotations

from datetime import date, datetime, timezone

from app.modules.players.nba_night import publication_cutoff


def test_cutoff_is_nine_paris_the_next_day_in_summer_time():
    assert publication_cutoff(date(2026, 10, 4)) == datetime(2026, 10, 5, 7, 0, tzinfo=timezone.utc)


def test_cutoff_follows_winter_time():
    assert publication_cutoff(date(2026, 12, 4)) == datetime(2026, 12, 5, 8, 0, tzinfo=timezone.utc)


def test_six_in_the_morning_is_still_before_the_cutoff():
    six_paris = datetime(2026, 10, 5, 4, 0, tzinfo=timezone.utc)  # 06:00 CEST
    assert six_paris < publication_cutoff(date(2026, 10, 4))
    after = datetime(2026, 10, 5, 7, 1, tzinfo=timezone.utc)        # 09:01 CEST
    assert after >= publication_cutoff(date(2026, 10, 4))

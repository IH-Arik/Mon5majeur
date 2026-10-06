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


def _stub_nights(monkeypatch, nights):
    from app.modules.players import nba_night

    async def _recent(now, limit=30):
        return nights

    monkeypatch.setattr(nba_night, "_recent_nights", _recent)
    return nba_night


def test_last_nights_results_stay_until_the_new_nights_first_tip_off(monkeypatch):
    import asyncio

    nights = [
        (date(2026, 10, 5), datetime(2026, 10, 5, 23, 0, tzinfo=timezone.utc)),
        (date(2026, 10, 4), datetime(2026, 10, 4, 23, 0, tzinfo=timezone.utc)),
    ]
    nba_night = _stub_nights(monkeypatch, nights)

    # 12:00 on the 5th: tonight (5th) has not tipped off -> still the 4th
    noon = datetime(2026, 10, 5, 10, 0, tzinfo=timezone.utc)
    assert asyncio.run(nba_night.results_night(noon)) == date(2026, 10, 4)
    # 23:30 UTC on the 5th: first tip-off passed -> the new night appears
    late = datetime(2026, 10, 5, 23, 30, tzinfo=timezone.utc)
    assert asyncio.run(nba_night.results_night(late)) == date(2026, 10, 5)


def test_fantasy_scores_appear_at_nine_not_before(monkeypatch):
    import asyncio

    nights = [(date(2026, 10, 4), datetime(2026, 10, 4, 23, 0, tzinfo=timezone.utc))]
    nba_night = _stub_nights(monkeypatch, nights)

    before = datetime(2026, 10, 5, 6, 59, tzinfo=timezone.utc)   # 08:59 Paris
    at_nine = datetime(2026, 10, 5, 7, 0, tzinfo=timezone.utc)   # 09:00 Paris
    assert asyncio.run(nba_night.published_night(before)) is None
    assert asyncio.run(nba_night.published_night(at_nine)) == date(2026, 10, 4)

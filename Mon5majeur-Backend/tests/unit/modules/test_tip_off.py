"""QA #9 2.3: the stored tip-off (and so the lock) must be the real one."""
from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import date, datetime, timezone

from app.modules.players.goalserve_client import _parse_tip_off


def _match(**attrs):
    return ET.fromstring("<match " + " ".join(f'{k}="{v}"' for k, v in attrs.items()) + "/>")


def test_ready_utc_timestamp_wins():
    m = _match(datetime_utc="04.10.2026 23:00", time="6:00 PM")
    assert _parse_tip_off(m, date(2026, 10, 4)) == datetime(2026, 10, 4, 23, 0, tzinfo=timezone.utc)


def test_local_time_falls_back_with_daylight_saving():
    m = _match(time="7:00 PM")
    # 19:00 Eastern in October is EDT (UTC-4) -> 23:00 UTC
    assert _parse_tip_off(m, date(2026, 10, 4)) == datetime(2026, 10, 4, 23, 0, tzinfo=timezone.utc)
    # in January it is EST (UTC-5) -> 00:00 UTC next day
    assert _parse_tip_off(m, date(2027, 1, 15)) == datetime(2027, 1, 16, 0, 0, tzinfo=timezone.utc)


def test_garbage_gives_none():
    assert _parse_tip_off(_match(time="soon"), date(2026, 10, 4)) is None

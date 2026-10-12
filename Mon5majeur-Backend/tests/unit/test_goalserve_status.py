import pytest

from app.modules.players.goalserve_client import _status_of


@pytest.mark.parametrize(
    "raw",
    ["Final", "Final/OT", "After Over Time", "After OT", "After 2nd OT", "Finished"],
)
def test_end_statuses_are_final(raw):
    assert _status_of(raw) == "final"


@pytest.mark.parametrize("raw", ["1st Quarter", "Halftime", "OT", ""])
def test_in_progress_statuses_stay_live(raw):
    assert _status_of(raw) == "live"


def test_not_started_is_scheduled():
    assert _status_of("Not Started") == "scheduled"

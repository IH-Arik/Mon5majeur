"""QA #9 6.1: multi-position players must not block a valid lineup."""
from __future__ import annotations

import itertools

import pytest

from app.modules.leagues.positions import can_fill_lineup, slots_for


def test_plain_positions():
    assert can_fill_lineup(["PG", "SG", "SF", "PF", "C"])


def test_generic_labels():
    assert can_fill_lineup(["G", "G", "F", "F", "C"])


def test_a_hybrid_takes_the_slot_that_is_free():
    # G-F can be a guard or a wing; F-C a wing or the center.
    assert can_fill_lineup(["PG", "G-F", "SF", "F-C", "C"])
    assert can_fill_lineup(["PG", "SG", "G-F", "F-C", "C-F"])


def test_order_of_addition_does_not_matter():
    labels = ["G-F", "F-C", "PG", "C", "SF"]
    for perm in itertools.permutations(labels):
        assert can_fill_lineup(list(perm)), perm


def test_two_centers_only_is_still_invalid():
    assert not can_fill_lineup(["PG", "SG", "SF", "C", "C"])


def test_three_guards_and_no_wing_is_invalid():
    assert not can_fill_lineup(["PG", "SG", "G", "PF", "C"])


def test_unknown_or_missing_label_is_invalid():
    assert not can_fill_lineup(["PG", "SG", "SF", "PF", None])
    assert not can_fill_lineup(["PG", "SG", "SF", "PF", ""])


def test_wrong_number_of_players():
    assert not can_fill_lineup(["PG", "SG", "SF", "PF"])


@pytest.mark.parametrize("label,expected", [
    ("G-F", {"B", "W"}), ("F-G", {"B", "W"}), ("F-C", {"W", "C"}),
    ("C-F", {"W", "C"}), ("pg", {"B"}), ("SF/PF", {"W"}), ("X", set()),
])
def test_slots_for(label, expected):
    assert slots_for(label) == expected

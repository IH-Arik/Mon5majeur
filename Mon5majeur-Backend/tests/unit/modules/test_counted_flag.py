"""Duels: who counts in the total ("counted"), the best 5 of 6 rule.

One rule (``best_five_flags``) decides the total (close, Results, Live) AND the
"counted" flag of every player: for every lineup the points of the players who
count (+3 with Chef Curry) are exactly the total, and Results and Live leave the
same player out, ties included.
"""
from __future__ import annotations

import asyncio
from itertools import product

import pytest

from app.modules.leagues import selection_service as sel_svc
from app.modules.leagues.substitution import best_five_flags, counted_player_ids
from tests.unit.modules.test_substitution_live import F, NIGHT, STARTERS, SUB, oid, row
from tests.unit.modules.test_substitution_live_scores import live_world, lineup
from tests.unit.modules.test_substitution_live_scores import sel as live_sel
from tests.unit.modules.test_substitution_result import (
    AWAY_PLAIN, SIXTH, _models, result_page, sel,
)

_ = _models   # the autouse fixture of the result tests


# ── the rule itself ──────────────────────────────────────────────────────────

def test_five_or_fewer_everybody_counts():
    assert best_five_flags([]) == []
    assert best_five_flags([3, 1, 2, 0, 9]) == [True] * 5


def test_six_slots_the_lowest_is_left_out():
    assert best_five_flags([40, 30, 20, 15, 10, 25]) == [True, True, True, True, False, True]
    assert best_five_flags([40, 30, 20, 5, 10, 25]) == [True, True, True, False, True, True]
    assert best_five_flags([1, 30, 20, 15, 10, 25]) == [False, True, True, True, True, True]


def test_a_tie_leaves_out_the_later_slot_so_the_6th_man_first():
    assert best_five_flags([40, 30, 20, 15, 10, 10]) == [True, True, True, True, True, False]
    assert best_five_flags([10, 30, 20, 15, 10, 40]) == [True, True, True, True, False, True]
    assert best_five_flags([7, 7, 7, 7, 7, 7]) == [True, True, True, True, True, False]


def test_decimals_are_compared_as_they_are():
    assert best_five_flags([20.5, 20.4, 30, 31, 32, 33]) == [True, False, True, True, True, True]


def test_counted_player_ids():
    slots = [{"id": f"s{i}"} for i in range(5)]
    scores = {"s0": 40, "s1": 30, "s2": 20, "s3": 15, "s4": 10, "six": 25}
    ids = counted_player_ids(slots, {"id": "six"}, lambda p: scores[p["id"]])
    assert ids == {"s0", "s1", "s2", "s3", "six"}
    assert counted_player_ids(slots, None, lambda p: scores[p["id"]]) == {"s0", "s1", "s2", "s3", "s4"}


# ── Results: the counted points are the total ────────────────────────────────

P = {1: 40, 2: 30, 3: 20, 4: 15, 5: 10}

# (name, stat rows). Player 1 is the 0-minute starter the substitute can replace.
LINEUPS = {
    "nobody absent": [row(n, sc, 30) for n, sc in P.items()],
    "#1 absent": [row(1, 0, 0)] + [row(n, sc, 30) for n, sc in P.items() if n != 1],
}
SUB_ROWS = {
    "no substitute": None,
    "substitute scores high": row(99, 33, 25),
    "substitute scores low": row(99, 3, 25),
    "substitute ties the lowest": row(99, 10, 25),
    "substitute did not play": row(99, 0, 0),
}
SIXTH_SCORES = {"none": None, "high": 45, "middle": 18, "low": 2, "tie with the lowest": 10, "tie at the top": 40}


def _all_cases():
    for lineup_name, sub_name, sixth_name, chef in product(LINEUPS, SUB_ROWS, SIXTH_SCORES, (False, True)):
        yield lineup_name, sub_name, sixth_name, chef


@pytest.mark.parametrize("lineup_name,sub_name,sixth_name,chef", list(_all_cases()))
def test_counted_points_are_exactly_the_total(monkeypatch, _models, lineup_name, sub_name, sixth_name, chef):
    rows = list(LINEUPS[lineup_name])
    if SUB_ROWS[sub_name] is not None:
        rows.append(SUB_ROWS[sub_name])
    sixth_score = SIXTH_SCORES[sixth_name]
    if sixth_score is not None:
        rows.append(row(77, sixth_score, 20))
    home = sel(
        substitute=SUB if SUB_ROWS[sub_name] is not None else None,
        sixth=SIXTH if sixth_score is not None else None,
        chef=chef,
    )
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=rows, home=home, away=AWAY_PLAIN)["H"]

    items = list(page["selection"]) + ([page["substitute"]] if page["substitute"] else [])
    counted = [i for i in items if i["counted"]]
    assert sum(i["score"] for i in counted) + (3 if chef else 0) == page["total_points"]
    # five players count with a 6th Man, otherwise the five slots: never more
    assert len(counted) == 5
    # the starter the substitute replaced never counts; a substitute who did not come in neither
    replaced = (page["substitution"] or {}).get("replaced_id")
    for i in page["selection"]:
        if i["id"] == replaced:
            assert not i["counted"]
    if page["substitution"] and page["substitution"]["status"] != "entered" and page["substitute"]:
        assert not page["substitute"]["counted"]


def test_a_tie_between_the_6th_man_and_a_starter_leaves_out_the_6th_man(monkeypatch, _models):
    rows = LINEUPS["nobody absent"] + [row(77, 10, 20)]            # the same 10 as #5
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=rows, home=sel(sixth=SIXTH), away=AWAY_PLAIN)["H"]
    flags = {i["id"]: i["counted"] for i in page["selection"]}
    assert flags[oid(77)] is False and flags[oid(5)] is True


def test_the_substitute_entered_and_left_out_is_flagged_not_counted(monkeypatch, _models):
    # #1 absent, the substitute scores 3, the 6th Man 18: the substitute is the weakest of the six
    rows = LINEUPS["#1 absent"] + [row(99, 3, 25), row(77, 18, 20)]
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=rows,
                       home=sel(substitute=SUB, sixth=SIXTH), away=AWAY_PLAIN)["H"]
    assert page["substitution"]["status"] == "entered"            # he came in...
    assert page["substitute"]["counted"] is False                  # ...but his 3 is not in the total
    assert page["total_points"] == 30 + 20 + 15 + 10 + 18


def test_the_opponents_hidden_lineup_carries_no_flags(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=[], home=sel(substitute=SUB),
                       away=sel(substitute=SUB, user="A"), match_status="scheduled", lock_in=3600)["A"]
    assert page["selection"] == [] and page["substitute"] is None


# ── Results and Live leave out the same player ───────────────────────────────

LIVE_CASES = [
    ("#1 absent", "substitute scores low", "middle"),
    ("#1 absent", "substitute ties the lowest", "tie with the lowest"),
    ("nobody absent", "substitute scores high", "tie with the lowest"),
    ("nobody absent", "no substitute", "tie with the lowest"),
    ("nobody absent", "no substitute", "low"),
    ("#1 absent", "substitute did not play", "middle"),
    ("#1 absent", "substitute scores high", "none"),
]


@pytest.mark.parametrize("lineup_name,sub_name,sixth_name", LIVE_CASES)
def test_results_and_live_leave_out_the_same_player(monkeypatch, _models, lineup_name, sub_name, sixth_name):
    rows = list(LINEUPS[lineup_name])
    if SUB_ROWS[sub_name] is not None:
        rows.append(SUB_ROWS[sub_name])
    if SIXTH_SCORES[sixth_name] is not None:
        rows.append(row(77, SIXTH_SCORES[sixth_name], 20))
    has_sub, has_sixth = SUB_ROWS[sub_name] is not None, SIXTH_SCORES[sixth_name] is not None

    page = result_page(monkeypatch, _models, status=[F, F, F], rows=rows,
                       home=sel(substitute=SUB if has_sub else None, sixth=SIXTH if has_sixth else None),
                       away=AWAY_PLAIN)["H"]
    results = {i["id"]: i["counted"] for i in page["selection"]}
    if page["substitute"]:
        results[page["substitute"]["id"]] = page["substitute"]["counted"]

    live_world(monkeypatch, status=[F, F, F], rows=rows)
    players, total, substitute, _ = lineup(
        live_sel(substitute=SUB if has_sub else None, sixth=SIXTH if has_sixth else None)
    )
    live = {oid(int(str(p.player_id), 16)): p.is_counted for p in players}
    if substitute is not None:
        live[oid(int(str(substitute.player_id), 16))] = substitute.is_counted

    assert live == results
    assert total == page["total_points"]

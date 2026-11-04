"""Substitute rule: who comes in, for whom, and when nothing is decided."""
import itertools

from app.modules.leagues.substitution import (
    ENTERED, NONE, NOT_ENTERED, PENDING, apply_substitution,
)


def p(pid, price, pos="PG"):
    return {"id": pid, "name": f"P{pid}", "position": pos, "price": f"{price}M"}


def lineup(*prices):
    return [p(str(i + 1), price) for i, price in enumerate(prices)]


SUB = p("99", 7)
ALL_PLAY = {"1": 30, "2": 30, "3": 30, "4": 30, "5": 30}


def test_full_lineup_all_play_substitute_does_not_enter():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, SUB, ALL_PLAY)
    assert r.status == NOT_ENTERED and not r.entered
    assert r.starters == s and r.replaced is None


def test_one_absent_starter_is_replaced():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, SUB, {**ALL_PLAY, "2": 0})
    assert r.status == ENTERED and r.replaced["id"] == "2"
    assert [x["id"] for x in r.starters] == ["1", "99", "3", "4", "5"]  # same slot


def test_substitute_who_played_zero_minute_still_enters():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, SUB, {**ALL_PLAY, "1": 0, "99": 0})
    assert r.entered and r.replaced["id"] == "1"


def test_two_absent_starters_replaces_the_most_expensive_only():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, SUB, {**ALL_PLAY, "2": 0, "3": 0})
    assert r.replaced["id"] == "2"
    assert "3" in [x["id"] for x in r.starters]  # the other absent starter stays


def test_lineup_without_substitute_is_untouched():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, None, {**ALL_PLAY, "1": 0})
    assert r.status == NONE and r.starters == s


def test_starter_who_played_one_minute_is_not_replaced():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, SUB, {**ALL_PLAY, "1": 1})
    assert r.status == NOT_ENTERED and r.starters == s


def test_price_tie_is_broken_by_lowest_id_whatever_the_order():
    base = [p("7", 12), p("3", 12), p("5", 9), p("2", 8), p("9", 6)]
    minutes = {"7": 0, "3": 0, "5": 30, "2": 30, "9": 30}
    for perm in itertools.permutations(base):
        r = apply_substitution(list(perm), SUB, minutes)
        assert r.replaced["id"] == "3"


def test_absent_starter_under_10m_is_not_eligible():
    s = lineup(9, 8, 7, 6, 5)
    r = apply_substitution(s, SUB, {"1": 0, "2": 0, "3": 30, "4": 30, "5": 30})
    assert r.status == NOT_ENTERED


def test_starter_at_exactly_10m_is_eligible():
    s = lineup(10, 8, 7, 6, 5)
    r = apply_substitution(s, SUB, {**ALL_PLAY, "1": 0})
    assert r.entered and r.replaced["id"] == "1"


def test_not_settled_decides_nothing():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, SUB, {**ALL_PLAY, "1": 0}, settled=False)
    assert r.status == PENDING and r.starters == s and r.replaced is None


def test_missing_minutes_count_as_zero_minute():
    # a game not final at closing (e.g. postponed) has no stat row at all
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, SUB, {"2": 30, "3": 30, "4": 30, "5": 30})
    assert r.entered and r.replaced["id"] == "1"
    assert apply_substitution(s, SUB, {**ALL_PLAY, "1": None}).replaced["id"] == "1"


def test_substitute_already_a_starter_is_ignored():
    s = lineup(15, 12, 10, 8, 5)
    r = apply_substitution(s, dict(s[3]), {**ALL_PLAY, "1": 0})
    assert r.status == NONE and r.starters == s


def test_prices_accept_floats_and_strings():
    s = [{"id": "1", "price": 15.0}, {"id": "2", "price": "12.5M"},
         {"id": "3", "price": "9"}, {"id": "4", "price": 8}, {"id": "5", "price": "5M"}]
    r = apply_substitution(s, SUB, {"1": 30, "2": 0, "3": 30, "4": 30, "5": 30})
    assert r.replaced["id"] == "2"


def test_inputs_are_not_modified():
    s = lineup(15, 12, 10, 8, 5)
    before = [dict(x) for x in s]
    apply_substitution(s, SUB, {**ALL_PLAY, "1": 0})
    assert s == before and SUB == p("99", 7)


def test_substitute_brings_no_bonus_from_the_replaced_starter():
    s = lineup(15, 12, 10, 8, 5)
    s[0]["bonus"] = "chef_curry"
    r = apply_substitution(s, SUB, {**ALL_PLAY, "1": 0})
    assert "bonus" not in r.starters[0]

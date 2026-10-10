"""QA #10 16: the batched duel scoring gives the numbers the old per-player
queries did (6th man = best 5 of 6, Chef Curry = +3)."""
from types import SimpleNamespace

from app.modules.leagues.selection_service import total_from_scores


def _sel(ids, sixth=None, chef=False):
    return SimpleNamespace(
        selected_players=[{"id": i} for i in ids],
        sixth_man_player={"id": sixth} if sixth else None,
        chef_curry=chef,
    )


SCORES = {"a": 0.0, "b": 10.4, "c": 0.0, "d": 0.0, "e": 17.6, "s": 12.0}


def test_plain_sum():
    # the report's own example: 0 + 10 + 0 + 0 + 18 = 28
    assert total_from_scores(_sel("abcde"), SCORES) == 28.0


def test_sixth_man_replaces_the_worst_starter():
    # best five of six: 17.6 + 12 + 10.4 + 0 + 0
    assert total_from_scores(_sel("abcde", sixth="s"), SCORES) == 40.0


def test_chef_curry_adds_three():
    assert total_from_scores(_sel("abcde", chef=True), SCORES) == 31.0


def test_unknown_player_counts_zero():
    assert total_from_scores(_sel("abcdz"), SCORES) == 10.4

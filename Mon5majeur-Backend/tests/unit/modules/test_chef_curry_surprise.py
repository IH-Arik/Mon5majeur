from types import SimpleNamespace

from app.modules.leagues.selection_service import total_from_scores


def _sel(chef=True, sixth=None):
    return SimpleNamespace(
        selected_players=[{"id": str(i)} for i in range(5)],
        sixth_man_player=sixth, chef_curry=chef,
    )


def test_no_point_yet_the_opponent_sees_0_not_3():
    assert total_from_scores(_sel(), {}, with_chef_curry=False) == 0


def test_the_player_and_the_published_result_count_the_bonus():
    scores = {str(i): 10.0 for i in range(5)}
    assert total_from_scores(_sel(), scores) == 53
    assert total_from_scores(_sel(), scores, with_chef_curry=False) == 50


def test_without_chef_curry_nothing_changes():
    scores = {str(i): 10.0 for i in range(5)}
    assert total_from_scores(_sel(chef=False), scores, with_chef_curry=False) == 50


def test_the_sixth_man_still_counts_best_5_of_6_while_hidden():
    scores = {"0": 1.0, "1": 10.0, "2": 10.0, "3": 10.0, "4": 10.0, "6": 20.0}
    sel = _sel(sixth={"id": "6"})
    assert total_from_scores(sel, scores, with_chef_curry=False) == 60

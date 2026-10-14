from types import SimpleNamespace

from app.modules.leagues.playoff_labels import label_of

SERIES = {"s-semi": "semi_final", "s-final": "final"}


def _match(**kw):
    base = dict(is_playoff=False, playoff_series_id=None, playoff_game_number=None)
    base.update(kw)
    return SimpleNamespace(**base)


def test_semi_final_game_2():
    m = _match(is_playoff=True, playoff_series_id="s-semi", playoff_game_number=2)
    assert label_of(m, SERIES) == ("semi_final", 2)


def test_final_game_1():
    m = _match(is_playoff=True, playoff_series_id="s-final", playoff_game_number=1)
    assert label_of(m, SERIES) == ("final", 1)


def test_regular_season_match_has_neither():
    assert label_of(_match(), SERIES) == (None, None)


def test_playoff_match_with_unknown_series_keeps_the_game_number():
    m = _match(is_playoff=True, playoff_series_id="gone", playoff_game_number=3)
    assert label_of(m, SERIES) == (None, 3)

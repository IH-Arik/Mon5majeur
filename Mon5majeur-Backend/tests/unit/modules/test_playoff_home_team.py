from types import SimpleNamespace

from app.modules.leagues.leaderboard_service import _home_team_id


def _user(auto_id):
    return SimpleNamespace(auto_id=auto_id)


def test_a_is_home():
    umap = {"A": _user(11), "B": _user(22)}
    assert _home_team_id(SimpleNamespace(home_user_id="A"), umap) == 11


def test_b_is_home():
    umap = {"A": _user(11), "B": _user(22)}
    assert _home_team_id(SimpleNamespace(home_user_id="B"), umap) == 22


def test_user_not_found():
    assert _home_team_id(SimpleNamespace(home_user_id="X"), {"A": _user(11)}) is None


def test_game_without_a_match():
    assert _home_team_id(None, {"A": _user(11)}) is None

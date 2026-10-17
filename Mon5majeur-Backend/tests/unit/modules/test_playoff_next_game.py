import asyncio
from types import SimpleNamespace
from unittest.mock import MagicMock, patch, AsyncMock

from app.modules.leagues import playoff_labels
from app.modules.leagues.leaderboard_service import _upcoming_matches


def _series(played=(1,)):
    return SimpleNamespace(id="S", games=[SimpleNamespace(game_number=n) for n in played])


def _match(status, day):
    return SimpleNamespace(status=status, match_day=day)


def test_the_scheduled_game_is_added_to_the_series():
    s = _series(played=(1,))
    by_game = {("S", 1): _match("completed", 7), ("S", 2): _match("upcoming", 8)}
    out = _upcoming_matches(s, by_game)
    assert [(n, m.match_day, m.status) for n, m in out] == [(2, 8, "upcoming")]


def test_a_game_already_in_the_played_list_is_not_repeated():
    s = _series(played=(1, 2))
    by_game = {("S", 2): _match("upcoming", 8)}
    assert _upcoming_matches(s, by_game) == []


def test_matches_of_other_series_are_ignored():
    s = _series(played=())
    by_game = {("OTHER", 1): _match("upcoming", 7), ("S", 1): _match("live", 7)}
    assert [n for n, _ in _upcoming_matches(s, by_game)] == [1]


def test_a_finished_series_has_nothing_to_come():
    s = _series(played=(1, 2))
    by_game = {("S", 1): _match("completed", 7), ("S", 2): _match("completed", 8)}
    assert _upcoming_matches(s, by_game) == []


class _Q:
    def __init__(self, row):
        self.row = row

    def sort(self, *a, **k):
        return self

    async def first_or_none(self):
        return self.row


def _next(row):
    fake = MagicMock()
    fake.find = MagicMock(return_value=_Q(row))
    with patch("app.modules.leagues.model.LeagueMatch", fake), patch.object(
        playoff_labels, "rounds_by_series", AsyncMock(return_value={"S": "final"})
    ):
        return asyncio.run(playoff_labels.next_playoff_label("L", "U"))


def test_next_match_of_a_finalist():
    row = SimpleNamespace(is_playoff=True, playoff_series_id="S", playoff_game_number=2)
    assert _next(row) == ("final", 2)


def test_qualified_player_with_no_match_to_come_has_no_next_match():
    assert _next(None) == (None, None)

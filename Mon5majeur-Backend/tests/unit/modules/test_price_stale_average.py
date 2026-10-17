import asyncio
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.modules.players import pricing


class _Query:
    def __init__(self, rows):
        self.rows = rows

    def sort(self, *a, **k):
        return self

    def limit(self, *a, **k):
        return self

    async def to_list(self):
        return self.rows

    async def count(self):
        return len(self.rows)


def _recompute(player, rows):
    fake = MagicMock()
    fake.find = MagicMock(return_value=_Query(rows))
    with patch.object(pricing, "PlayerGameStats", fake):
        return asyncio.run(pricing.recompute_player_price(player, date(2026, 10, 17)))


def _player(**kw):
    base = dict(id="P", daily_price=3.0, avg_fantasy_score=29.0, games_played=4,
                price_computed_at=None, recent_two_scores=[None, None])
    base.update(kw)
    return SimpleNamespace(**base)


def test_a_player_with_no_scored_game_no_longer_keeps_an_old_average():
    p = _recompute(_player(), rows=[])
    assert p.daily_price == 3.0
    assert p.avg_fantasy_score == 0.0 and p.games_played == 0


def test_a_player_with_scored_games_still_gets_average_and_price_from_them():
    rows = [SimpleNamespace(score_computed=True, did_not_play=False, fantasy_score=float(v),
                            nba_date=date(2026, 10, d))
            for d, v in [(10, 30), (9, 20), (8, 10)]]
    p = _recompute(_player(), rows=rows)
    assert p.avg_fantasy_score == 20.0
    assert p.daily_price == pricing.compute_price(rows)

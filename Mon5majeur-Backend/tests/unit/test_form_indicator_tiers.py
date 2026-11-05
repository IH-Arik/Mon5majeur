"""Price tiers of the form indicator: no gap between tiers, ranking per tier."""
import pytest

from app.modules.players import form_indicator as fi


@pytest.mark.parametrize(
    "price,tier",
    [(3, 0), (10, 0), (11, 1), (22, 1), (23, 2), (35, 2), (50, 2), (10.0, 0), (22.0, 1)],
)
def test_tier_index_bounds(price, tier):
    assert fi.tier_index(price) == tier


def test_every_integer_price_has_exactly_one_tier():
    for price in range(3, 51):
        assert 0 <= fi.tier_index(price) < len(fi.PRICE_TIERS)
    assert {fi.tier_index(p) for p in range(3, 51)} == {0, 1, 2}


class _P:
    def __init__(self, price):
        self.daily_price = price
        self.form = None

    async def save(self):
        pass


@pytest.mark.asyncio
async def test_each_tier_gets_its_own_hot_and_cold():
    cands = []
    for price in (5, 15, 30):
        for i in range(10):
            cands.append(fi._Candidate(player=_P(price), base_avg=20.0, delta_pct=(i - 4.5) / 10))
    for tier in fi._split_by_tier(cands):
        assert len(tier) == 10
        await fi._apply_tier(tier)
    for price in (5, 15, 30):
        forms = [c.player.form for c in cands if c.player.daily_price == price]
        assert forms.count("HOT") == 1 and forms.count("COLD") == 1

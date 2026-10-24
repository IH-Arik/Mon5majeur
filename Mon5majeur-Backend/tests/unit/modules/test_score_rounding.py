import pytest

from app.modules.players.scoring import round_score


@pytest.mark.parametrize("raw, expected", [
    (42, 29),    # 29.4
    (45, 32),    # 31.5 (float gave 31.4999... -> 31): SGA 10/20
    (5, 4),      # 3.5
    (15, 11),    # 10.5 (Python round() gave 10, half to even)
    (25, 18),    # 17.5
    (44, 31),    # 30.8
    (44.5, 31),  # 31.15
    (0, 0),
    (-5, -4),    # -3.5, away from zero
    (-2, -1),    # -1.4
])
def test_exact_rounding(raw, expected):
    assert round_score(raw) == expected

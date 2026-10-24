"""
Fantasy Score formula (spec §4.2):
    Base       = PTS + REB + AST + STL + BLK − TO
    2pt_made   = fg_made  − 3pt_made          ← NEVER use Goalserve `two_pt` field
    2pt_att    = fg_att   − 3pt_att
    2pt_missed = 2pt_att  − 2pt_made
    3pt_missed = 3pt_att  − 3pt_made
    ft_missed  = ft_att   − ft_made
    Efficiency = (3pt_made×+2) + (3pt_missed×−2)
               + (2pt_made×+1) + (2pt_missed×−1)
               + (ft_made ×+0.5) + (ft_missed×−0.5)
    Score      = round((Base + Efficiency) × 0.7)   ← single integer rounding at the end

The × 0.7 and the rounding are done in exact decimal, .5 rounded up (away from
zero): in floating point 45 × 0.7 = 31.4999… and Python's round() also
rounds .5 to the even number, so a raw total ending in 5 (5, 15, 25, 35, 45…)
lost a point (SGA 10/20: 31 instead of 32). The formula itself is unchanged.
"""
from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

from app.modules.players.model import PlayerGameStats


def compute_fantasy_score(s: PlayerGameStats) -> float:
    if s.did_not_play or s.minutes_played == 0:
        return 0.0

    base = (
        s.points
        + s.rebounds
        + s.assists
        + s.steals
        + s.blocks
        - s.turnovers
    )

    fg2_made   = s.field_goals_made      - s.threepoint_made
    fg2_att    = s.field_goals_attempted - s.threepoint_attempted
    fg2_missed = fg2_att - fg2_made
    fg3_missed = s.threepoint_attempted  - s.threepoint_made
    ft_missed  = s.freethrow_attempted   - s.freethrow_made

    efficiency = (
        s.threepoint_made * 2   - fg3_missed * 2
        + fg2_made * 1          - fg2_missed * 1
        + s.freethrow_made * 0.5 - ft_missed * 0.5
    )

    return float(round_score(base + efficiency))


def round_score(raw: float) -> int:
    """round(raw × 0.7), exact: raw is a whole or half number (free throws
    count 0.5), so str() is exact and Decimal has no floating-point error."""
    value = Decimal(str(raw)) * Decimal("0.7")
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def compute_and_stamp(s: PlayerGameStats) -> PlayerGameStats:
    s.fantasy_score = compute_fantasy_score(s)
    s.score_computed = True
    return s

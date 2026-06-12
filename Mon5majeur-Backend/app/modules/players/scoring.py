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
"""
from __future__ import annotations

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

    return float(round((base + efficiency) * 0.7))


def compute_and_stamp(s: PlayerGameStats) -> PlayerGameStats:
    s.fantasy_score = compute_fantasy_score(s)
    s.score_computed = True
    return s

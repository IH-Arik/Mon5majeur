"""
Player price algorithm (spec §4.3) — recomputed daily at 09:00 Paris:

    Inputs: last 5 PLAYED games (absences excluded), each game's final rounded Fantasy Score.

    Step 1 — Weighted average:
        n=0 → floor price (3M), return directly
        n=1 → weighted_avg = that score
        n=2 → simple average
        n≥3 → sort ascending; best×1, worst×1, middle×2 each; divide by sum of coefficients (4/6/8)

    Step 2 — Zone divisor applied to weighted_avg:
        ≤ 16      → ÷ 1.2   (bench)
        > 16–≤ 25 → ÷ 1.1   (starters)
        > 25      → ÷ 1.0   (superstars)

    Step 3 — round() → integer price in millions, clamped [3, 50].
"""
from __future__ import annotations

from datetime import date

from app.modules.players.model import Player, PlayerGameStats

_MIN_PRICE = 3
_MAX_PRICE = 50


def compute_price(last_5: list[PlayerGameStats]) -> float:
    """Given up to 5 most-recent PLAYED game-stat records, return new price (integer M)."""
    scored = [g for g in last_5 if g.score_computed and not g.did_not_play]
    if not scored:
        return float(_MIN_PRICE)

    games = scored[:5]
    n = len(games)
    s = sorted(g.fantasy_score for g in games)   # ascending: s[0]=worst, s[-1]=best

    if n == 1:
        weighted_avg = s[0]
    elif n == 2:
        weighted_avg = (s[0] + s[1]) / 2
    else:
        # n = 3,4,5 → coef_sum = 4, 6, 8
        coef_sum = 1 + 1 + 2 * (n - 2)
        weighted_avg = (s[-1] + s[0] + sum(s[1:-1]) * 2) / coef_sum

    if weighted_avg <= 16:
        divisor = 1.2
    elif weighted_avg <= 25:
        divisor = 1.1
    else:
        divisor = 1.0

    price = round(weighted_avg / divisor)
    return float(max(_MIN_PRICE, min(_MAX_PRICE, price)))


async def recompute_player_price(player: Player, today: date) -> Player:
    """Fetch last-5 played game stats, compute price, update player in-place (caller saves)."""
    last_5 = (
        await PlayerGameStats.find(
            PlayerGameStats.player_id == player.id,
            PlayerGameStats.score_computed == True,   # noqa: E712
            PlayerGameStats.did_not_play == False,    # noqa: E712
        )
        .sort(-PlayerGameStats.nba_date)
        .limit(5)
        .to_list()
    )

    player.daily_price = compute_price(last_5)
    player.price_computed_at = today

    if last_5:
        scores = [g.fantasy_score for g in last_5 if g.fantasy_score is not None]
        player.avg_fantasy_score = round(sum(scores) / len(scores), 2) if scores else 0.0
        player.games_played = await PlayerGameStats.find(
            PlayerGameStats.player_id == player.id,
            PlayerGameStats.did_not_play == False,  # noqa: E712
        ).count()

    return player

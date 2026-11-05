"""
Form indicator (HOT/COLD) — spec Part 1 §4.0.

Relative ranking, not a fixed threshold: within tonight's ELIGIBLE pool
(has a game today, >=5 played games on record, base_avg > 0), the top 10%
by delta_pct gets HOT, the bottom 10% gets COLD, everyone else (including
ineligible players) gets neutral (form=None, no badge rendered).

The ranking is done separately inside each PRICE TIER (see ``PRICE_TIERS``),
so every tier has its own HOT and COLD players instead of the badges
landing almost only on the cheap players.

    recent_avg = mean of last 2 played games' Fantasy Score
    base_avg   = mean of last 5 played games' Fantasy Score
    delta_pct  = (recent_avg - base_avg) / base_avg

Direction guard: a top-10% player with a negative delta_pct renders
NEUTRAL, not HOT (and the mirror case for COLD) — the badge must never
contradict the direction it claims to show.

Recomputed once daily in the same 09:00 Paris cron pass as pricing
(called right after ``PlayerService.recompute_all_prices()``) — never
recomputed per-request.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from app.modules.players.model import NBAGame, Player, PlayerGameStats

_TOP_BOTTOM_FRACTION = 0.10

# Price tiers (in M), the ONLY place the bounds live. Each entry is the
# inclusive upper bound of a tier; the last tier is open-ended. Tier 1 = 3..10,
# tier 2 = 11..22, tier 3 = 23 and above. Comparing against the upper bound
# only means no price can fall between two tiers, even a non-integer one.
PRICE_TIERS: tuple[float | None, ...] = (10, 22, None)


def tier_index(price: float) -> int:
    """Index in ``PRICE_TIERS`` of the tier the price belongs to."""
    for idx, upper in enumerate(PRICE_TIERS):
        if upper is None or price <= upper:
            return idx
    return len(PRICE_TIERS) - 1


@dataclass
class _Candidate:
    player: Player
    base_avg: float
    delta_pct: float


async def _clear_form(player: Player) -> None:
    if player.form is not None:
        player.form = None
        await player.save()


async def compute_and_store_form_indicators(today: date) -> int:
    """Returns the number of players whose `form` field changed."""
    games_today = await NBAGame.find(NBAGame.nba_date == today).to_list()
    from app.modules.players.teams_playing import TeamsPlaying

    teams_playing = TeamsPlaying(games_today)

    all_active = await Player.find(Player.is_active == True).to_list()  # noqa: E712

    candidates: list[_Candidate] = []
    for player in all_active:
        if not teams_playing.plays(player.team_name, player.team_goalserve_id):
            await _clear_form(player)
            continue

        last_5 = (
            await PlayerGameStats.find(
                PlayerGameStats.player_id == player.id,
                PlayerGameStats.score_computed == True,   # noqa: E712
                PlayerGameStats.did_not_play == False,     # noqa: E712
            )
            .sort(-PlayerGameStats.nba_date)
            .limit(5)
            .to_list()
        )

        if len(last_5) < 5:
            await _clear_form(player)
            continue

        base_avg = sum(g.fantasy_score or 0.0 for g in last_5) / 5
        if base_avg <= 0:
            await _clear_form(player)
            continue

        recent_avg = sum(g.fantasy_score or 0.0 for g in last_5[:2]) / 2
        delta_pct = (recent_avg - base_avg) / base_avg
        candidates.append(_Candidate(player=player, base_avg=base_avg, delta_pct=delta_pct))

    updated = 0
    for tier_candidates in _split_by_tier(candidates):
        updated += await _apply_tier(tier_candidates)

    return updated


def _split_by_tier(candidates: list[_Candidate]) -> list[list[_Candidate]]:
    tiers: list[list[_Candidate]] = [[] for _ in PRICE_TIERS]
    for c in candidates:
        tiers[tier_index(c.player.daily_price)].append(c)
    return tiers


async def _apply_tier(candidates: list[_Candidate]) -> int:
    # Deterministic sort: delta_pct descending; ties at the 10% boundary
    # rank the higher base_avg first (spec — an unstable order would make
    # badges flicker between recomputations).
    candidates.sort(key=lambda c: (-c.delta_pct, -c.base_avg))

    pool_size = len(candidates)
    badge_count = round(pool_size * _TOP_BOTTOM_FRACTION)

    updated = 0
    for idx, c in enumerate(candidates):
        new_form: str | None = None
        if badge_count > 0 and idx < badge_count:
            new_form = "HOT" if c.delta_pct > 0 else None
        elif badge_count > 0 and idx >= pool_size - badge_count:
            new_form = "COLD" if c.delta_pct < 0 else None

        if c.player.form != new_form:
            c.player.form = new_form
            await c.player.save()
            updated += 1

    return updated

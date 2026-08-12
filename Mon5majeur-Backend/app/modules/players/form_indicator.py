"""
Form indicator (HOT/COLD) — spec Part 1 §4.0.

Relative ranking, not a fixed threshold: within tonight's ELIGIBLE pool
(has a game today, >=5 played games on record, base_avg > 0), the top 10%
by delta_pct gets HOT, the bottom 10% gets COLD, everyone else (including
ineligible players) gets neutral (form=None, no badge rendered).

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
    team_ids_playing: set[str] = set()
    for g in games_today:
        team_ids_playing.add(g.home_team_id)
        team_ids_playing.add(g.away_team_id)

    all_active = await Player.find(Player.is_active == True).to_list()  # noqa: E712

    candidates: list[_Candidate] = []
    for player in all_active:
        if player.team_goalserve_id not in team_ids_playing:
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

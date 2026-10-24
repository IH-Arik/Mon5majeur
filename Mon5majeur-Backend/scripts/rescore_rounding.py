"""Re-score the stored fantasy scores with the exact rounding (scoring.round_score).

    python scripts/rescore_rounding.py            # dry run: what would change
    python scripts/rescore_rounding.py --apply    # backup, then write

Before the fix, a raw total ending in 5 (5, 15, 25, 35, 45...) lost one point
(float 45 x 0.7 = 31.4999...). The dry run lists, night by night, every stat
line whose score changes (old -> new), the duels whose score changes and
whether a winner would change, and the Global League totals that change.
Nothing is written.

--apply, only after the dry run was approved:
  1. stops if a duel winner would change (that needs a decision: standings,
     play-off series and rewards already followed that result);
  2. writes a JSON backup of the stat lines, duels and Global archive of the
     affected nights BEFORE any write;
  3. updates the stat lines, then for each affected night that is already
     published re-scores its duels, rebuilds the standings of those leagues
     and the Global League archive. A night not yet published is left to the
     09:00 close.
"""
from __future__ import annotations

import asyncio
import json
import sys
import tempfile
from collections import defaultdict
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.session import init_db
from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
from app.modules.leagues.model import League, LeagueMatch
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.model import Player, PlayerGameStats
from app.modules.players.night_publication import published_marks
from app.modules.players.scoring import compute_fantasy_score


async def _changes() -> dict:
    """{night: [(stat, old, new)]} of the computed lines whose score changes."""
    out = defaultdict(list)
    for s in await PlayerGameStats.find(PlayerGameStats.score_computed == True).to_list():  # noqa: E712
        new = compute_fantasy_score(s)
        if s.fantasy_score is None or float(s.fantasy_score) != new:
            out[s.nba_date].append((s, s.fantasy_score, new))
    return out


async def _duels(night, new_scores: dict) -> list[tuple]:
    """(league auto_id, match, old totals, new totals, winner changes)."""
    from app.modules.leagues.selection_service import total_from_scores

    stats = await PlayerGameStats.find(PlayerGameStats.nba_date == night).to_list()
    before = {str(s.player_id): float(s.fantasy_score or 0) for s in stats if s.score_computed}
    after = {**before, **new_scores}
    rows = []
    for m in await LeagueMatch.find(LeagueMatch.nba_date == night).to_list():
        league = await League.get(m.league_id)
        if league is None:
            continue

        async def total(uid, scores):
            sel = await FlutterPlayerSelection.find_one(
                FlutterPlayerSelection.user_id == uid,
                FlutterPlayerSelection.league_auto_id == league.auto_id,
                FlutterPlayerSelection.match_day == m.match_day,
            )
            return total_from_scores(sel, scores) if sel else 0.0

        old = (await total(m.home_user_id, before), await total(m.away_user_id, before))
        new = (await total(m.home_user_id, after), await total(m.away_user_id, after))
        if old != new:
            # Tie -> home wins (engine rule).
            flips = (old[0] >= old[1]) != (new[0] >= new[1])
            rows.append((league.auto_id, m, old, new, flips))
    return rows


async def main() -> None:
    apply = "--apply" in sys.argv
    await init_db()

    changes = await _changes()
    if not changes:
        print("no stored score changes with the exact rounding")
        return
    nights = sorted(changes)
    published = await published_marks(nights)
    total_lines = sum(len(v) for v in changes.values())
    print(f"{total_lines} stat line(s) on {len(nights)} night(s) change")

    any_flip = False
    plan = []
    for night in nights:
        lines = changes[night]
        tag = "published" if night in published else "not published yet"
        print(f"\n== {night} ({tag}): {len(lines)} line(s)")
        for s, old, new in lines:
            p = await Player.get(s.player_id)
            print(f"  {p.full_name if p else s.player_id}: {old} -> {new}")
        new_scores = {str(s.player_id): new for s, _old, new in lines}
        duels = await _duels(night, new_scores) if night in published else []
        for auto_id, m, old, new, flips in duels:
            any_flip = any_flip or flips
            flag = "   <-- WINNER CHANGES" if flips else ""
            print(f"  league {auto_id} day {m.match_day}{' (play-off)' if m.is_playoff else ''}: "
                  f"{old[0]}-{old[1]} -> {new[0]}-{new[1]}{flag}")
        archived = await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.nba_date == night).count()
        print(f"  Global archive rows that night: {archived} (rebuilt on --apply)")
        plan.append((night, lines, night in published, duels))

    if not apply:
        print("\ndry run: nothing written")
        return
    if any_flip:
        print("\nSTOP: a duel winner would change; decide first, nothing written")
        return

    out = Path(tempfile.gettempdir()) / f"rescore_rounding_{datetime.now():%Y%m%d_%H%M%S}.json"
    backup = {}
    for night, lines, _pub, _duels_ in plan:
        backup[str(night)] = {
            "stats": [json.loads(s.model_dump_json()) for s, _o, _n in lines],
            "matches": [json.loads(m.model_dump_json())
                        for m in await LeagueMatch.find(LeagueMatch.nba_date == night).to_list()],
            "global_archive": [json.loads(a.model_dump_json()) for a in
                               await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.nba_date == night).to_list()],
        }
    out.write_text(json.dumps(backup, default=str, indent=1), encoding="utf-8")
    print("backup written before any change:", out)

    from app.modules.leagues.engine import score_match_day, update_standings
    from app.modules.leagues.global_score_service import archive_daily_scores

    for night, lines, is_published, _duels_ in plan:
        for s, _old, new in lines:
            s.fantasy_score = new
            await s.save()
        if not is_published:
            continue
        days = defaultdict(set)
        for m in await LeagueMatch.find(LeagueMatch.nba_date == night).to_list():
            days[m.league_id].add(m.match_day)
        for league_id, mds in days.items():
            for md in mds:
                await score_match_day(league_id, md, night)
            await update_standings(league_id)
        await archive_daily_scores(night)
        print(f"{night}: {len(lines)} line(s) updated, {len(days)} league(s) re-scored, Global archive rebuilt")
    print("restart the api so the cached results are dropped")


if __name__ == "__main__":
    asyncio.run(main())

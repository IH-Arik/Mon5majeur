"""Re-read one night from Goalserve and correct its fantasy scores (Arik QA item 1).

    python scripts/resync_night.py 2026-10-20            # dry run: before/after diff
    python scripts/resync_night.py 2026-10-20 --apply    # backup, then write

Dry run (default) writes nothing: it fetches the night's box scores again and
prints every stat line Goalserve corrected after the game, with the fantasy
score before and after, then the duels and the Global League totals of that
night that would change.

--apply, only after the dry run was shown and approved:
  1. writes a JSON backup (stat lines, duels, Global archive of the night) to
     the temp folder BEFORE any write;
  2. updates the corrected stat lines and scores them again (scoring formula
     unchanged);
  3. re-scores the night's duels, rebuilds the standings of those leagues and
     the Global League archive of that night.
Prices are recomputed by the next 09:00 close as usual.
"""
from __future__ import annotations

import asyncio
import json
import sys
import tempfile
from collections import defaultdict
from copy import copy
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.session import init_db
from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
from app.modules.leagues.model import League, LeagueMatch
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.goalserve_client import fetch_scores_for_date
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.scoring import compute_fantasy_score

_FIELDS = (
    "minutes_played", "did_not_play", "points", "rebounds", "assists", "steals",
    "blocks", "turnovers", "field_goals_made", "field_goals_attempted",
    "threepoint_made", "threepoint_attempted", "freethrow_made", "freethrow_attempted",
)


async def _diff(night: date) -> list[dict]:
    games = await fetch_scores_for_date(night)
    out = []
    for g in games:
        for p in g["players"]:
            stored = await PlayerGameStats.find_one(
                PlayerGameStats.goalserve_game_id == g["goalserve_game_id"],
                PlayerGameStats.goalserve_player_id == p["goalserve_player_id"],
            )
            if stored is None:
                continue
            changed = {f: (getattr(stored, f), p[f]) for f in _FIELDS if getattr(stored, f) != p[f]}
            if not changed:
                continue
            fresh = copy(stored)
            for f in _FIELDS:
                setattr(fresh, f, p[f])
            out.append({
                "stat": stored, "player_id": stored.player_id, "name": p["full_name"],
                "changes": changed, "fp_before": stored.fantasy_score,
                "fp_after": round(compute_fantasy_score(fresh)),
            })
    return out


async def _duel_totals(night: date, new_fp: dict) -> list[str]:
    from app.modules.leagues.selection_service import total_from_scores

    lines = []
    matches = await LeagueMatch.find(LeagueMatch.nba_date == night).to_list()
    stats = await PlayerGameStats.find(PlayerGameStats.nba_date == night).to_list()
    before = {str(s.player_id): float(s.fantasy_score or 0) for s in stats if s.score_computed}
    after = {**before, **{str(k): float(v) for k, v in new_fp.items()}}
    for m in matches:
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
            lines.append(f"  league {league.auto_id} day {m.match_day}: {old[0]}-{old[1]} -> {new[0]}-{new[1]}")
    return lines


async def main() -> None:
    args = [a for a in sys.argv[1:] if a != "--apply"]
    apply = "--apply" in sys.argv
    if len(args) != 1:
        print(__doc__)
        return
    night = date.fromisoformat(args[0])
    await init_db()

    diffs = await _diff(night)
    print(f"night {night}: {len(diffs)} stat line(s) corrected by Goalserve since the import")
    for d in diffs:
        changes = ", ".join(f"{k} {a}->{b}" for k, (a, b) in d["changes"].items())
        print(f"  {d['name']}: FP {d['fp_before']} -> {d['fp_after']} ({changes})")
    duel_lines = await _duel_totals(night, {d["player_id"]: d["fp_after"] for d in diffs})
    print(f"duels that change: {len(duel_lines)}")
    print("\n".join(duel_lines))

    if not apply:
        print("dry run: nothing written")
        return
    if not diffs:
        print("nothing to correct")
        return

    out = Path(tempfile.gettempdir()) / f"resync_{night}_{datetime.now():%Y%m%d_%H%M%S}.json"
    stats = await PlayerGameStats.find(PlayerGameStats.nba_date == night).to_list()
    matches = await LeagueMatch.find(LeagueMatch.nba_date == night).to_list()
    archive = await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.nba_date == night).to_list()
    out.write_text(json.dumps({
        "stats": [json.loads(s.model_dump_json()) for s in stats],
        "matches": [json.loads(m.model_dump_json()) for m in matches],
        "global_archive": [json.loads(a.model_dump_json()) for a in archive],
    }, default=str, indent=1), encoding="utf-8")
    print("backup written before any change:", out)

    from app.modules.leagues.engine import score_match_day, update_standings
    from app.modules.leagues.global_score_service import archive_daily_scores
    from app.modules.players.repository import PlayerRepository
    from app.modules.players.service import PlayerService

    svc = PlayerService(PlayerRepository())
    await svc.sync_scores_for_date(night, allow_frozen=True)
    for game in await NBAGame.find(NBAGame.nba_date == night).to_list():
        if game.status == "final":
            await svc.finalize_game_scores(game.goalserve_id)

    days = defaultdict(set)
    for m in matches:
        days[m.league_id].add(m.match_day)
    for league_id, mds in days.items():
        for md in mds:
            await score_match_day(league_id, md, night)
        await update_standings(league_id)
    await archive_daily_scores(night)
    print(f"done: scores corrected, {len(days)} league(s) re-scored, Global archive rebuilt")
    print("restart the api so the cached published results are dropped")


if __name__ == "__main__":
    asyncio.run(main())

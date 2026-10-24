"""Remove the extra copies of one matchup on one night, keeping the real game
(Robin 10/24: Philadelphia-Cleveland 10/22 stored 3 times: the real 329192, a
copy stuck "live 7-7" (141511) and one with an empty Goalserve id, plus 19
duplicated stat lines).

    python scripts/remove_orphan_games.py 2026-10-22 329192            # dry run
    python scripts/remove_orphan_games.py 2026-10-22 329192 --apply    # backup, then delete

The game to KEEP is given by its Goalserve id; every other record of the same
matchup that night is removed with its own stat lines. The kept game and its
stat lines are not touched. Standings and archives are not recomputed (Robin:
the 22/10 standings are not affected); the script says if a removed stat line
was the one counted for a player that night.
"""
from __future__ import annotations

import asyncio
import json
import sys
import tempfile
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.session import init_db
from app.modules.players.model import NBAGame, PlayerGameStats


async def main() -> None:
    args = [a for a in sys.argv[1:] if a != "--apply"]
    apply = "--apply" in sys.argv
    if len(args) != 2:
        print(__doc__)
        return
    night, keep_id = date.fromisoformat(args[0]), args[1]
    await init_db()

    keep = await NBAGame.find_one(NBAGame.goalserve_id == keep_id)
    if keep is None or keep.nba_date != night:
        print(f"game {keep_id} not found on {night}: nothing done")
        return
    games = await NBAGame.find(
        NBAGame.nba_date == night,
        NBAGame.home_team_id == keep.home_team_id,
        NBAGame.away_team_id == keep.away_team_id,
    ).to_list()
    extra = [g for g in games if g.id != keep.id]
    print(f"keep {keep.goalserve_id!r} {keep.away_team_name} @ {keep.home_team_name} "
          f"{keep.status} {keep.away_score}-{keep.home_score}")
    kept_players = {s.player_id for s in await PlayerGameStats.find(
        PlayerGameStats.goalserve_game_id == keep.goalserve_id).to_list()}

    to_delete_stats = []
    for g in extra:
        rows = await PlayerGameStats.find(PlayerGameStats.goalserve_game_id == g.goalserve_id).to_list()
        # Only this matchup's own rows: an empty id must not catch other games' rows.
        rows = [r for r in rows if r.nba_date == night]
        to_delete_stats += rows
        only_here = [r for r in rows if r.player_id not in kept_players]
        print(f"remove {g.goalserve_id!r} status {g.status} {g.away_score}-{g.home_score} "
              f"created {g.created_at}: {len(rows)} stat line(s), "
              f"{len(only_here)} for players absent from the real game")
    if not extra:
        print("no extra copy")
        return
    if not apply:
        print("dry run: nothing written")
        return

    out = Path(tempfile.gettempdir()) / f"orphan_games_{night}_{datetime.now():%Y%m%d_%H%M%S}.json"
    out.write_text(json.dumps({
        "games": [json.loads(g.model_dump_json()) for g in extra],
        "stats": [json.loads(s.model_dump_json()) for s in to_delete_stats],
    }, default=str, indent=1), encoding="utf-8")
    print("backup written before any change:", out)
    for s in to_delete_stats:
        await s.delete()
    for g in extra:
        await g.delete()
    print(f"removed {len(extra)} game(s) and {len(to_delete_stats)} stat line(s)")


if __name__ == "__main__":
    asyncio.run(main())

"""QA #12 data corrections (items 1-3). DRY RUN by default: nothing is written
without --apply, and --apply must only be run after the client approved the
dry-run output.

    python scripts/qa12_fix_players_and_game.py merge                 # list the pairs
    python scripts/qa12_fix_players_and_game.py merge --apply         # merge them
    python scripts/qa12_fix_players_and_game.py game 329138           # show the plan
    python scripts/qa12_fix_players_and_game.py game 329138 --apply   # finalize it

merge: a player with no team_name that has exactly one teamed twin with the same
normalized name is the duplicate created by an old stats import. Its stat rows
move to the real (teamed) record, which keeps its official name, team, price and
the lineups pointing at it; the real record takes over the Goalserve id so the
next imports land on it; the duplicate is saved to a JSON backup, then deleted.
A pair is skipped (and reported) when the duplicate is referenced by a saved
lineup, when the same game would have two stat rows, or when the name has more
than one teamed twin. Prices and the scoring formula are never touched.

game: marks the game final and stamps the fantasy score of its players
(overtime included). Afterwards the affected night still needs its duels,
standings and Global archive recomputed; the script prints what to run.
"""
from __future__ import annotations

import asyncio
import json
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.session import init_db
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.espn_roster import normalize_name
from app.modules.players.model import NBAGame, Player, PlayerGameStats


async def _selection_refs(player_id) -> int:
    pid = str(player_id)
    return await FlutterPlayerSelection.find(
        {"$or": [
            {"selected_players.id": pid},
            {"sixth_man_player.id": pid},
        ]}
    ).count()


async def merge(apply: bool) -> None:
    players = await Player.find_all().to_list()
    by_key: dict[str, list[Player]] = defaultdict(list)
    for p in players:
        by_key[normalize_name(p.full_name)].append(p)

    merged = 0
    nights: set = set()
    backup: list[dict] = []
    for key, group in sorted(by_key.items()):
        dups = [p for p in group if not p.team_name]
        real = [p for p in group if p.team_name]
        if not dups or not real:
            continue
        for dup in dups:
            if len(real) != 1:
                print(f"SKIP  {key}: {len(real)} teamed twins, decide by hand")
                continue
            twin = real[0]
            refs = await _selection_refs(dup.id)
            stats = await PlayerGameStats.find(PlayerGameStats.player_id == dup.id).to_list()
            twin_stats = await PlayerGameStats.find(PlayerGameStats.player_id == twin.id).to_list()
            clash = {s.goalserve_game_id for s in stats} & {s.goalserve_game_id for s in twin_stats}
            if refs or clash:
                print(f"SKIP  {key}: lineup refs={refs} clashing games={sorted(clash)}")
                continue
            print(
                f"MERGE {key}: '{dup.full_name}' gid={dup.goalserve_id} ({len(stats)} stat rows)"
                f" -> '{twin.full_name}' ({twin.team_name}) gid {twin.goalserve_id} -> {dup.goalserve_id}"
            )
            nights.update(s.nba_date for s in stats)
            merged += 1
            if not apply:
                continue
            backup.append({"duplicate": json.loads(dup.model_dump_json()),
                           "kept": str(twin.id), "moved_stats": len(stats)})
            new_gid = dup.goalserve_id
            await dup.delete()  # frees the unique goalserve_id
            for s in stats:
                s.player_id = twin.id
                await s.save()
            twin.goalserve_id = new_gid
            await twin.save()

    print(f"\n{'merged' if apply else 'would merge'}: {merged if apply else sum(1 for _ in nights) and ''}")
    print("nights whose scores, duels, standings and Global archive must be recomputed:")
    for n in sorted(nights):
        print("  ", n)
    if apply and backup:
        out = Path(f"qa12_merged_players_{datetime.now():%Y%m%d_%H%M%S}.json")
        out.write_text(json.dumps(backup, default=str, indent=2), encoding="utf-8")
        print("backup written:", out)


async def game(game_id: str, apply: bool) -> None:
    g = await NBAGame.find_one(NBAGame.goalserve_id == game_id)
    if not g:
        print("game not found")
        return
    stats = await PlayerGameStats.find(PlayerGameStats.goalserve_game_id == game_id).to_list()
    todo = [s for s in stats if not s.score_computed]
    print(f"game {game_id} {g.nba_date} status={g.status} score {g.home_score}-{g.away_score}; "
          f"{len(todo)}/{len(stats)} stat rows without a computed score")
    if not apply:
        print("dry run: would set status=final and stamp those rows")
        return
    from app.modules.players.service import PlayerService

    g.status = "final"
    await g.save()
    count = await PlayerService().finalize_game_scores(game_id)
    print("stamped", count, "rows")
    print(f"next: archive_daily_scores({g.nba_date}) and run_daily_close({g.nba_date}) for the duels")


async def main() -> None:
    args = sys.argv[1:]
    apply = "--apply" in args
    args = [a for a in args if a != "--apply"]
    await init_db()
    if args and args[0] == "merge":
        await merge(apply)
    elif len(args) == 2 and args[0] == "game":
        await game(args[1], apply)
    else:
        print(__doc__)


if __name__ == "__main__":
    asyncio.run(main())

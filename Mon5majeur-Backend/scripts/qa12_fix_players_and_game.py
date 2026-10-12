"""QA #12 data corrections (items 1-3). DRY RUN by default: nothing is written
without --apply, and --apply must only be run after the client approved the
dry-run output.

    python scripts/qa12_fix_players_and_game.py merge                 # list the groups
    python scripts/qa12_fix_players_and_game.py merge --apply         # merge them
    python scripts/qa12_fix_players_and_game.py hide "Anthony Edwards" ...   # mask dormant twins
    python scripts/qa12_fix_players_and_game.py recompute 2026-10-10 ...   # duels, standings, Global archive
    python scripts/qa12_fix_players_and_game.py game 329138           # show the plan
    python scripts/qa12_fix_players_and_game.py game 329138 --apply   # finalize it

merge: every group of 2+ player records sharing a normalized name (no accents,
punctuation or Jr/Sr suffix, lowercase) is one real person. The record that is
kept is the one with a team, then the active one, then the one most used
(stat rows + saved lineups); it keeps its official name, team and price. For
each other record, in this order:
  - its stat rows move to the kept record,
  - every saved lineup that points at it (Global/duel selections, 6th man,
    legacy lineup slots, fantasy teams) is re-pointed to the kept record,
  - the kept record takes over its Goalserve id (the one the next imports
    carry), then the record is deleted.
A copy of everything about to change is written to a JSON file BEFORE the first
write. A group is skipped and reported when two records of it are active on
different teams, or when the same game would end up with two stat rows. Records
that are already inactive and unused (the dormant star twins) are left alone:
they are already masked. Prices and the scoring formula are never touched.

game: marks the game final and stamps the fantasy score of its players
(overtime included). Afterwards the affected nights still need their duels,
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

from beanie import PydanticObjectId

from app.database.session import init_db
from app.modules.fantasy_teams.model import FantasyTeam
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.lineups.model import LineupSlot
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


async def _usage(p: Player) -> tuple[int, int, int]:
    stats = await PlayerGameStats.find(PlayerGameStats.player_id == p.id).count()
    sel = await _selection_refs(p.id)
    slots = await LineupSlot.find(LineupSlot.player_id == p.id).count()
    return stats, sel, slots


async def _repoint(old: Player, kept: Player) -> dict[str, int]:
    """Re-point every saved reference of `old` to `kept`."""
    old_id, new_id = str(old.id), str(kept.id)
    done: dict[str, int] = {}
    col = FlutterPlayerSelection.get_motor_collection()
    r = await col.update_many(
        {"selected_players.id": old_id},
        {"$set": {"selected_players.$[e].id": new_id,
                  "selected_players.$[e].name": kept.full_name}},
        array_filters=[{"e.id": old_id}],
    )
    done["selections"] = r.modified_count
    r = await col.update_many(
        {"sixth_man_player.id": old_id},
        {"$set": {"sixth_man_player.id": new_id, "sixth_man_player.name": kept.full_name}},
    )
    done["sixth_man"] = r.modified_count
    r = await LineupSlot.get_motor_collection().update_many(
        {"player_id": old.id},
        {"$set": {"player_id": kept.id, "player_name": kept.full_name,
                  "player_goalserve_id": kept.goalserve_id}},
    )
    done["lineup_slots"] = r.modified_count
    r = await FantasyTeam.get_motor_collection().update_many(
        {"player_ids": old.id},
        {"$set": {"player_ids.$[e]": kept.id}},
        array_filters=[{"e": old.id}],
    )
    done["fantasy_teams"] = r.modified_count
    return done


async def merge(apply: bool) -> None:
    by_key: dict[str, list[Player]] = defaultdict(list)
    for p in await Player.find_all().to_list():
        by_key[normalize_name(p.full_name)].append(p)

    plan: list[dict] = []
    nights: set = set()
    for key, group in sorted(by_key.items()):
        if len(group) < 2:
            continue
        usage = {p.id: await _usage(p) for p in group}
        # Dormant twins (inactive and unused) are already masked: not merged.
        live = [p for p in group if p.is_active or sum(usage[p.id]) > 0]
        if len(live) < 2:
            continue
        kept = max(
            live,
            key=lambda p: (bool(p.team_name), p.is_active, sum(usage[p.id]), p.full_name),
        )
        others = [p for p in live if p.id != kept.id]
        active_teams = {p.team_name for p in live if p.is_active and p.team_name}
        if len(active_teams) > 1:
            print(f"SKIP  {key}: active records on different teams {sorted(active_teams)}")
            continue
        kept_games = {
            s.goalserve_game_id
            for s in await PlayerGameStats.find(PlayerGameStats.player_id == kept.id).to_list()
        }
        for old in others:
            stats = await PlayerGameStats.find(PlayerGameStats.player_id == old.id).to_list()
            clash = {s.goalserve_game_id for s in stats} & kept_games
            real_clash = {g for g in clash if not str(g).startswith("qa_")}
            if real_clash:
                print(f"SKIP  {key}: '{old.full_name}' shares games {sorted(real_clash)} with the kept record")
                continue
            # QA test games (qa_fresh_N): the copy on the old record is dropped.
            dropped = [s for s in stats if s.goalserve_game_id in clash]
            stats = [s for s in stats if s.goalserve_game_id not in clash]
            kept_games |= {s.goalserve_game_id for s in stats}
            kept_stats = await PlayerGameStats.find(PlayerGameStats.player_id == kept.id).to_list()
            candidates = [s for s in stats + kept_stats if not str(s.goalserve_game_id).startswith("qa_")]
            newest = max(candidates, key=lambda s: s.nba_date) if candidates else None
            plan.append({"key": key, "old": old, "kept": kept, "stats": stats, "dropped": dropped,
                         "usage": usage[old.id],
                         "gid": newest.goalserve_player_id if newest else None})
            nights.update(s.nba_date for s in stats)
            if dropped:
                print(f"      ({len(dropped)} QA test stat row(s) {sorted(clash)} dropped from the old record)")
            print(
                f"MERGE {key}: '{old.full_name}' (gid={old.goalserve_id}, team={old.team_name}, "
                f"active={old.is_active}, stats={usage[old.id][0]}, lineups={usage[old.id][1]}, "
                f"slots={usage[old.id][2]}) -> KEEP '{kept.full_name}' "
                f"(gid={kept.goalserve_id}, team={kept.team_name}, active={kept.is_active}, "
                f"stats={usage[kept.id][0]}, lineups={usage[kept.id][1]})"
            )

    print(f"\n{len(plan)} records to merge {'now' if apply else '(dry run, nothing written)'}")
    print("nights to recompute afterwards (scores, duels, standings, Global archive):")
    for n in sorted(nights):
        print("  ", n)
    if not apply or not plan:
        return

    # Backup first: every document about to change, on disk before any write.
    out = Path(f"qa12_merge_backup_{datetime.now():%Y%m%d_%H%M%S}.json")
    backup = []
    for item in plan:
        pid = [str(item["old"].id)]
        sels = await FlutterPlayerSelection.find(
            {"$or": [{"selected_players.id": pid[0]}, {"sixth_man_player.id": pid[0]}]}
        ).to_list()
        backup.append({
            "old": json.loads(item["old"].model_dump_json()),
            "kept_before": json.loads(item["kept"].model_dump_json()),
            "stat_ids": [str(s.id) for s in item["stats"]],
            "dropped_stats": [json.loads(s.model_dump_json()) for s in item["dropped"]],
            "selection_ids": [str(s.id) for s in sels],
            "selections_before": [json.loads(s.model_dump_json()) for s in sels],
        })
    out.write_text(json.dumps(backup, default=str, indent=2), encoding="utf-8")
    print("backup written before any change:", out)

    for item in plan:
        old, kept, stats = item["old"], item["kept"], item["stats"]
        moved = await _repoint(old, kept)
        old_team_gid = old.team_goalserve_id
        await old.delete()  # frees the unique goalserve_id
        for s in item["dropped"]:
            await s.delete()
        for s in stats:
            s.player_id = kept.id
            await s.save()
        # The Goalserve id the real box scores carry (read from the newest real
        # stat row, never from a legacy placeholder id), so the next import
        # lands on the kept record.
        gid = item["gid"]
        if gid and gid != kept.goalserve_id:
            holder = await Player.find_one(Player.goalserve_id == gid)
            if holder is None:
                kept.goalserve_id = gid
                if old_team_gid:
                    kept.team_goalserve_id = old_team_gid
            else:
                print(f"   warning: id {gid} is held by another record, not changed")
        if not kept.is_active:
            kept.is_active = True
        await kept.save()
        print(f"merged {item['key']}: {len(stats)} stat rows, re-pointed {moved}")


async def hide(names: list[str], apply: bool) -> None:
    """Mask (is_active=False), never delete. A dormant twin is one with no stat
    row and no saved lineup pointing at it."""
    wanted = {normalize_name(n) for n in names}
    groups: dict[str, list[Player]] = defaultdict(list)
    for p in await Player.find_all().to_list():
        if normalize_name(p.full_name) in wanted:
            groups[normalize_name(p.full_name)].append(p)
    for key, group in sorted(groups.items()):
        used = [(p, *(await _usage(p))) for p in group]
        keep = max(used, key=lambda t: (t[1] + t[2], t[0].is_active))[0]
        for p, n_stats, refs, _slots in used:
            tag = "KEEP" if p.id == keep.id else "HIDE"
            print(f"{tag} {key}: '{p.full_name}' gid={p.goalserve_id} active={p.is_active} stats={n_stats} lineups={refs}")
            if tag == "HIDE":
                if n_stats or refs:
                    print("   has activity: left alone, decide by hand")
                elif apply and p.is_active:
                    p.is_active = False
                    await p.save()


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


async def _duel_scores(league, match, night):
    from app.modules.leagues.selection_service import score_full_selection

    async def one(uid):
        sel = await FlutterPlayerSelection.find_one(
            FlutterPlayerSelection.user_id == uid,
            FlutterPlayerSelection.league_auto_id == league.auto_id,
            FlutterPlayerSelection.match_day == match.match_day,
        )
        return await score_full_selection(sel, night) if sel else 0.0

    return await one(match.home_user_id), await one(match.away_user_id)


async def recompute(nights: list[str], apply: bool) -> None:
    """Re-score the duels, standings and Global archive of the given nights
    (run once, after the merge and the game fix). Every step is idempotent: the
    duel scores are overwritten, the standings are rebuilt from the completed
    matches, the Global archive is an upsert."""
    from datetime import date as _date

    from app.modules.leagues.engine import score_match_day, update_standings
    from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
    from app.modules.leagues.global_score_service import _score_selection, archive_daily_scores
    from app.modules.leagues.model import League, LeagueMatch

    touched: set = set()
    for text in nights:
        night = _date.fromisoformat(text)
        print(f"== {night}")
        matches = await LeagueMatch.find(LeagueMatch.nba_date == night).to_list()
        days = {(m.league_id, m.match_day) for m in matches}
        for league_id, md in sorted(days, key=lambda t: (str(t[0]), t[1])):
            league = await League.get(league_id)
            if not league:
                continue
            for m in [m for m in matches if m.league_id == league_id and m.match_day == md]:
                new_h, new_a = await _duel_scores(league, m, night)
                flag = "" if (new_h, new_a) == (m.home_score, m.away_score) else "   <-- changes"
                print(f"  league {league.auto_id} md {md}: {m.home_score}-{m.away_score} -> {new_h}-{new_a}{flag}")
            if apply:
                await score_match_day(league_id, md, night)
            touched.add(league_id)
        global_rows = await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.nba_date == night).to_list()
        changed = 0
        for row in global_rows:
            sel = await FlutterPlayerSelection.find_one(
                FlutterPlayerSelection.user_id == row.user_id,
                FlutterPlayerSelection.nba_date == night,
            )
            new = await _score_selection(sel.selected_players, night) if sel else row.total_points
            if round(new, 2) != round(row.total_points, 2):
                changed += 1
        print(f"  Global archive: {len(global_rows)} rows, {changed} would change")
        if apply:
            await archive_daily_scores(night)
    if apply:
        for league_id in touched:
            await update_standings(league_id)
        print("standings rebuilt for", len(touched), "leagues")
    else:
        print("dry run: nothing written")


async def main() -> None:
    args = sys.argv[1:]
    apply = "--apply" in args
    args = [a for a in args if a != "--apply"]
    await init_db()
    if args and args[0] == "merge":
        await merge(apply)
    elif len(args) >= 2 and args[0] == "hide":
        await hide(args[1:], apply)
    elif len(args) >= 2 and args[0] == "recompute":
        await recompute(args[1:], apply)
    elif len(args) == 2 and args[0] == "game":
        await game(args[1], apply)
    else:
        print(__doc__)


if __name__ == "__main__":
    asyncio.run(main())

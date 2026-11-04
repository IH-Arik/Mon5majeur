"""Dry-run of the substitute rule on restored data.

    MONGODB_URI=mongodb://127.0.0.1:27017 MONGODB_DB_NAME=dryrun_m5m \
        python scripts/dryrun/compare.py

Part A  recomputes the exported nights with the CURRENT code (Global League
        archive and duel close, the real functions) and compares with the
        scores that were published. Lineups saved before the substitute existed
        must give zero difference.
Part B  adds a few fictitious lineups with a substitute (own fictitious league
        and users) and prints what happens.

Runs only on a local database created by restore_local.py (see _guard.py).
"""
from __future__ import annotations

import asyncio
import json
import sys
from collections import defaultdict
from datetime import date, datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from beanie import PydanticObjectId
from pymongo import MongoClient

from _guard import assert_local, assert_marker, assert_no_env_files, fail

FICT_LEAGUE_AUTO_ID = 990001


def oid_for(label: str) -> PydanticObjectId:
    import hashlib

    return PydanticObjectId(hashlib.sha256(label.encode()).hexdigest()[:24])


async def main() -> None:
    assert_no_env_files()                                 # before the app reads any setting
    from app.core.config import get_settings

    s = get_settings()                                    # what the app would REALLY connect to
    assert_local(s.MONGODB_URI, s.MONGODB_DB_NAME)
    sync = MongoClient(s.MONGODB_URI, serverSelectionTimeoutMS=5000)[s.MONGODB_DB_NAME]
    assert_marker(sync)
    nights = [date.fromisoformat(n) for n in sync["_dryrun_marker"].find_one({"purpose": "dryrun"})["nights"]]

    from app.database.session import init_db

    await init_db()
    report: list[str] = []
    say = lambda line="": (print(line), report.append(line))

    published = await snapshot_published(nights)
    await recompute(nights)
    diffs = await compare_with(published, nights, say)

    await real_lineups_with_absent_starters(nights, say)
    await fictitious_lineups(nights, say)

    out = Path("dryrun_report.txt")
    out.write_text("\n".join(report), encoding="utf-8")
    say(f"\nReport written to {out.resolve()}")
    sys.exit(1 if diffs else 0)


# ── Part A ───────────────────────────────────────────────────────────────────

async def snapshot_published(nights):
    from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
    from app.modules.leagues.model import LeagueMatch

    snap = {"global": {}, "duels": {}}
    for n in nights:
        for r in await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.nba_date == n).to_list():
            snap["global"][(str(r.user_id), n)] = float(r.total_points)
        for m in await LeagueMatch.find(LeagueMatch.nba_date == n).to_list():
            if m.status == "completed":
                snap["duels"][str(m.id)] = (m.home_score, m.away_score, str(m.winner_id))
    return snap


async def recompute(nights):
    from app.modules.leagues import engine
    from app.modules.leagues.global_score_service import archive_daily_scores
    from app.modules.leagues.model import LeagueMatch

    for n in nights:
        await archive_daily_scores(n)                                  # the real Global League close
        groups = {(m.league_id, m.match_day) for m in await LeagueMatch.find(LeagueMatch.nba_date == n).to_list()}
        for league_id, match_day in sorted(groups, key=str):
            await engine.score_match_day(league_id, match_day, n)      # the real duel close


async def compare_with(published, nights, say):
    from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
    from app.modules.leagues.model import LeagueMatch

    diffs = []
    g_total = d_total = 0
    for n in nights:
        for r in await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.nba_date == n).to_list():
            key = (str(r.user_id), n)
            if key not in published["global"]:
                continue
            g_total += 1
            if round(published["global"][key], 2) != round(float(r.total_points), 2):
                diffs.append(f"GLOBAL {n} user {key[0][:8]}…  published {published['global'][key]}  recomputed {r.total_points}")
        for m in await LeagueMatch.find(LeagueMatch.nba_date == n).to_list():
            if str(m.id) not in published["duels"]:
                continue
            d_total += 1
            old = published["duels"][str(m.id)]
            new = (m.home_score, m.away_score, str(m.winner_id))
            if (old[0], old[1]) != (new[0], new[1]) or old[2] != new[2]:
                diffs.append(f"DUEL   {n} league-day {str(m.league_id)[:8]}…/{m.match_day}  published {old}  recomputed {new}")
    say("=" * 78)
    say("PART A - recomputed with the new code vs published scores")
    say(f"nights: {', '.join(str(n) for n in nights)}")
    say(f"Global League scores compared: {g_total}    duels compared: {d_total}")
    say(f"DIFFERENCES: {len(diffs)}")
    for d in diffs[:60]:
        say("  " + d)
    if len(diffs) > 60:
        say(f"  … and {len(diffs) - 60} more")
    if not diffs:
        say("-> zero difference")
    return diffs


# ── Part A2 ──────────────────────────────────────────────────────────────────

async def real_lineups_with_absent_starters(nights, say):
    """Every REAL lineup that would have triggered a substitution had it had a
    substitute: a starter of 10M+ with 0 minute, or with no stats row at all
    (an absent player usually has no row). Also checks, on the real ids, that
    the substitution service sees the same minutes as the stats rows."""
    from app.modules.leagues.model import League
    from app.modules.leagues.substitution_service import _minutes, resolve_substitution
    from app.modules.lineups.compat_model import FlutterPlayerSelection
    from app.modules.players.model import Player, PlayerGameStats

    def price(p):
        try:
            return float(str(p.get("price", "0")).replace("M", ""))
        except ValueError:
            return 0.0

    leagues = {l.auto_id: l for l in await League.find_all().to_list()}
    names = {str(p.id): p.full_name for p in await Player.find_all().to_list()}
    say("\n" + "=" * 78)
    say("PART A2 - real lineups that would have triggered a substitution")
    mismatches = seen = no_row = 0
    found = []
    for night in nights:
        rows = {str(r.player_id): r for r in await PlayerGameStats.find(PlayerGameStats.nba_date == night).to_list()}
        # a neutral hypothetical substitute: median scorer among players of <=10M who played
        cheap = sorted(
            (i for i, r in rows.items() if not r.did_not_play and (r.minutes_played or 0) > 0
             and i in names and r.fantasy_score is not None),
            key=lambda i: rows[i].fantasy_score)
        sels = await FlutterPlayerSelection.find(FlutterPlayerSelection.nba_date == night).to_list()
        for sel in sels:
            starters = sel.selected_players
            minutes = await _minutes(starters, night)             # what the real service sees
            for p in starters:
                pid = str(p["id"])
                direct = None if pid not in rows else (0 if rows[pid].did_not_play else (rows[pid].minutes_played or 0))
                seen += 1
                no_row += direct is None
                if direct != minutes.get(pid):
                    mismatches += 1
            absent = [p for p in starters if price(p) >= 10 and (minutes.get(str(p["id"])) or 0) == 0]
            if not absent:
                continue
            in_lineup = {str(p["id"]) for p in starters}
            sub_id = next((i for i in cheap if i not in in_lineup), None)
            res = None
            if sub_id is not None:
                sub = {"id": sub_id, "name": names.get(sub_id, ""), "position": "", "price": "7M"}
                res = await resolve_substitution(starters, sub, night, closing=True)
            lg = leagues.get(sel.league_auto_id)
            found.append((night, lg.type if lg else "?", sel.league_auto_id, str(sel.user_id)[:8], absent, minutes, rows, res, sub_id, names))
    say(f"Check on real ids: {seen} starters looked up, {no_row} have no stats row, "
        f"minutes seen by the service differ from the stats rows for {mismatches} of them")
    if mismatches:
        say("  !!! the substitution service does NOT find the minutes of some real starters")
    by_night = {}
    for f in found:
        by_night.setdefault(f[0], []).append(f)
    say(f"Real lineups with an absent 10M+ starter: {len(found)}  "
        + "  ".join(f"{n}: {len(by_night.get(n, []))}" for n in nights))
    for night in nights:
        say(f"\n  --- night {night}")
        for (_n, kind, auto_id, user, absent, minutes, rows, res, sub_id, nm) in by_night.get(night, []):
            ab = "; ".join(
                f"{nm.get(str(p['id']), p['id'])} {p['price']} ({'no stats row' if str(p['id']) not in rows else '0 minute'})"
                for p in absent)
            who = ""
            if res is not None:
                who = (f" -> replaced: {nm.get(str(res.replaced['id']), '?')} {res.replaced['price']}" if res.entered
                       else f" -> {res.status}")
            say(f"  {kind:<7} league {auto_id}  user {user}…  absent: {ab}{who}")
    say("\n(the hypothetical substitute is the median scorer among those who played; only the rule's decision matters here)")


# ── Part B ───────────────────────────────────────────────────────────────────

async def fictitious_lineups(nights, say):
    from app.modules.leagues import engine
    from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
    from app.modules.leagues.global_score_service import archive_daily_scores
    from app.modules.leagues.model import League, LeagueMatch
    from app.modules.leagues.substitution_service import resolve_substitution
    from app.modules.lineups.compat_model import FlutterPlayerSelection
    from app.modules.players.model import Player, PlayerGameStats

    say("\n" + "=" * 78)
    say("PART B - fictitious lineups with a substitute (own league and users)")
    night = nights[-1]
    stats = {str(r.player_id): r for r in await PlayerGameStats.find(PlayerGameStats.nba_date == night).to_list()}
    players = {str(p.id): p for p in await Player.find({"_id": {"$in": [r.player_id for r in stats.values()]}}).to_list()}

    # an absent player usually has NO stats row: take the 10M+ starters of the real
    # lineups of that night who have none
    missing = {}
    for sel in await FlutterPlayerSelection.find(FlutterPlayerSelection.nba_date == night).to_list():
        for p in sel.selected_players:
            try:
                if str(p["id"]) not in stats and float(str(p.get("price", "0")).replace("M", "")) >= 10:
                    missing[str(p["id"])] = p
            except ValueError:
                pass
    for extra in await Player.find({"_id": {"$in": [PydanticObjectId(i) for i in missing]}}).to_list():
        players[str(extra.id)] = extra

    def minutes(pid):
        r = stats.get(pid)
        return 0 if r is None or r.did_not_play else (r.minutes_played or 0)

    def pts(pid):
        return stats[pid].fantasy_score if pid in stats else 0

    def entry(pid):
        p = players[pid]
        return {"id": pid, "name": p.full_name, "position": p.position or "", "price": f"{p.daily_price:g}M"}

    ids = [i for i in stats if i in players and stats[i].score_computed]
    played_high = sorted((i for i in ids if players[i].daily_price >= 10 and minutes(i) > 0),
                         key=lambda i: -stats[i].fantasy_score)
    absent_high = [i for i in ids if players[i].daily_price >= 10 and minutes(i) == 0] + [
        i for i in missing if i in players and players[i].daily_price >= 10]
    played_low = sorted((i for i in ids if players[i].daily_price < 10 and minutes(i) > 0),
                        key=lambda i: -stats[i].fantasy_score)
    absent_low = [i for i in ids if players[i].daily_price < 10 and minutes(i) == 0]
    cheap_played = [i for i in ids if players[i].daily_price <= 10 and minutes(i) > 0 and stats[i].fantasy_score > 0]
    cheap_dnp = [i for i in ids if players[i].daily_price <= 10 and minutes(i) == 0]
    say(f"night {night}: starters of 10M+ with 0 minute available: {len(absent_high)}; "
        f"cheap substitutes who played: {len(cheap_played)}; cheap substitutes at 0 minute: {len(cheap_dnp)}")

    scenarios = []                      # (label, starter ids, substitute id, sixth id, chef)
    if len(played_high) >= 5 and cheap_played:
        scenarios.append(("all played, substitute does not enter", played_high[:5], cheap_played[0], None, False))
    if len(played_high) >= 4 and absent_high and cheap_played:
        scenarios.append(("one 10M+ starter at 0 minute", played_high[:4] + [absent_high[0]], cheap_played[0], None, False))
        scenarios.append(("... same, with Chef Curry", played_high[:4] + [absent_high[0]], cheap_played[0], None, True))
        if len(played_high) >= 5:
            scenarios.append(("... same, with a 6th Man", played_high[:4] + [absent_high[0]], cheap_played[0], played_high[4], False))
        if cheap_dnp:
            scenarios.append(("... substitute at 0 minute too", played_high[:4] + [absent_high[0]], cheap_dnp[0], None, False))
    if len(played_high) >= 3 and len(absent_high) >= 2 and cheap_played:
        scenarios.append(("two 10M+ starters at 0 minute", played_high[:3] + absent_high[:2], cheap_played[0], None, False))
    if len(played_high) >= 4 and absent_low and cheap_played:
        scenarios.append(("absent starter under 10M (no replacement)", played_high[:4] + [absent_low[0]], cheap_played[0], None, False))
    if not scenarios:
        say("not enough data on this night to build fictitious lineups")
        return

    league = await League.find_one(League.auto_id == FICT_LEAGUE_AUTO_ID)
    if league is None:
        league = await League(name="Dry-run league", type="private", budget=100, max_size=10,
                              status="regular_season", auto_id=FICT_LEAGUE_AUTO_ID).insert()
    glob = await League.find_one(League.type == "global")
    rows = []
    for k, (label, starters, sub, sixth, chef) in enumerate(scenarios, start=1):
        user, rival = oid_for(f"fict-user-{k}"), oid_for(f"fict-rival-{k}")
        base = dict(league_id=league.id, league_auto_id=FICT_LEAGUE_AUTO_ID, match_day=k,
                    submitted_at=datetime.now(timezone.utc), nba_date=night)
        sel = FlutterPlayerSelection(
            user_id=user, selected_players=[entry(i) for i in starters],
            substitute_player=entry(sub), substitute_set_at=datetime.now(timezone.utc),
            sixth_man_player=entry(sixth) if sixth else None, chef_curry=chef, **base)
        rival_sel = FlutterPlayerSelection(user_id=rival, selected_players=[entry(i) for i in played_high[:5]], **base)
        await sel.insert(); await rival_sel.insert()
        await LeagueMatch(league_id=league.id, match_day=k, nba_date=night, home_user_id=user, away_user_id=rival).insert()
        if glob is not None:
            await FlutterPlayerSelection(
                user_id=user, league_id=glob.id, league_auto_id=glob.auto_id or 0, match_day=900 + k,
                submitted_at=datetime.now(timezone.utc), nba_date=night,
                selected_players=[entry(i) for i in starters], substitute_player=entry(sub)).insert()
        rows.append((label, k, user, sel, starters, sub, sixth, chef))

    if glob is not None:
        await archive_daily_scores(night)
    for k in range(1, len(scenarios) + 1):
        await engine.score_match_day(league.id, k, night)

    for label, k, user, sel, starters, sub, sixth, chef in rows:
        res = await resolve_substitution(sel.selected_players, sel.substitute_player, night, closing=True)
        plain_6 = sorted([pts(i) for i in starters] + ([pts(sixth)] if sixth else []), reverse=True)[:5]
        plain_total = round(sum(plain_6 if sixth else [pts(i) for i in starters]) + (3 if chef else 0), 2)
        duel = await LeagueMatch.find_one(LeagueMatch.league_id == league.id, LeagueMatch.match_day == k)
        glob_row = await GlobalLeagueDailyScore.find_one(
            GlobalLeagueDailyScore.user_id == user, GlobalLeagueDailyScore.nba_date == night) if glob else None
        say(f"\n[{k}] {label}")
        for i in starters:
            tag = "  <- replaced" if res.entered and str(res.replaced["id"]) == i else ""
            say(f"      starter {players[i].full_name:<24}{players[i].daily_price:>4g}M  {minutes(i):>3} min  {pts(i):>5g} pts{tag}")
        say(f"      substitute {players[sub].full_name:<21}{players[sub].daily_price:>4g}M  {minutes(sub):>3} min  {stats[sub].fantasy_score:>5g} pts  -> {res.status}")
        if sixth:
            say(f"      6th Man {players[sixth].full_name:<24}{players[sixth].daily_price:>4g}M  {minutes(sixth):>3} min  {stats[sixth].fantasy_score:>5g} pts")
        say(f"      without the substitute: {plain_total}   |   duel (home) with it: {duel.home_score}   "
            f"|   Global League with it: {glob_row.total_points if glob_row else 'n/a'}")


if __name__ == "__main__":
    asyncio.run(main())

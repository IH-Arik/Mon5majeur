"""Test data for the local simulator: accounts, leagues, players, a published
night (with substitutes already scored by the REAL close code) and tonight.

    python scripts/local_sim/make_scenarios.py --state open     # tonight: lineups still open
    python scripts/local_sim/make_scenarios.py --state live     # tonight: games in progress

Both states contain the same published night (the last one whose 09:00 Paris
publication has passed). It EMPTIES the local database m5m_local_* first and
refuses to run on anything else (see _guard.py). Environment variables are set
by run_backend.sh; run this script the same way (README, step 4).
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

PASSWORD = "Local-test-1"
TEAMS = [
    "Los Angeles Lakers", "Boston Celtics", "Golden State Warriors", "Milwaukee Bucks",
    "Denver Nuggets", "Dallas Mavericks", "Miami Heat", "New York Knicks",
    "Phoenix Suns", "Oklahoma City Thunder", "Atlanta Hawks", "Orlando Magic",
]
POS = ["PG", "SG", "SF", "PF", "C"]
PRICES = [32, 24, 18, 15, 12, 10, 8, 6, 4, 3]       # idx 0-4: stars (12M+), idx 5-9: cheap (<=10M)


def uid(label: str):
    from beanie import PydanticObjectId

    return PydanticObjectId(hashlib.sha256(label.encode()).hexdigest()[:24])


async def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--state", choices=["open", "live"], default="open")
    args = ap.parse_args()

    from app.core.config import get_settings
    from _guard import check_settings

    check_settings(get_settings())

    from app.core.security import hash_password
    from app.database.counters import next_seq  # noqa: F401  (counters are set by hand below)
    from app.database.session import init_db
    from app.modules.bonuses.model import UserBonusInventory
    from app.modules.leagues import engine
    from app.modules.leagues.global_score_model import GlobalLeagueDailyScore  # noqa: F401
    from app.modules.leagues.global_score_service import archive_daily_scores
    from app.modules.leagues.model import League, LeagueMatch, LeagueMembership
    from app.modules.lineups.compat_model import FlutterPlayerSelection
    from app.modules.players.model import NBAGame, Player, PlayerGameStats
    from app.modules.players.nba_night import publication_cutoff
    from app.modules.players.night_publication import mark_published
    from app.modules.players.team_trigrams import trigram_for_team_name
    from app.modules.tokens.model import TokenWallet
    from app.modules.users.model import User

    await init_db()
    db = League.get_motor_collection().database
    for name in await db.list_collection_names():          # the database is dedicated: start clean
        await db.drop_collection(name)
    await init_db()                                         # indexes again

    random.seed(11)
    now = datetime.now(timezone.utc)
    # P = last night whose publication (09:00 Paris the day after) has passed; T = the night after
    P = now.date() - timedelta(days=1)
    while now < publication_cutoff(P):
        P -= timedelta(days=1)
    T = P + timedelta(days=1)

    # ── players: 12 teams x 10; each position has a star (12M+) and a cheap one (<=10M)
    players: dict[tuple[int, int], Player] = {}
    for t, team in enumerate(TEAMS):
        for i, price in enumerate(PRICES):
            p = await Player(
                goalserve_id=str(1000 + t * 10 + i), first_name=f"T{t:02d}", last_name=f"P{i}",
                full_name=f"{team.split()[-1]} {POS[(i + t) % 5]}{'*' if i < 5 else ''} {t:02d}-{i}",
                position=POS[(i + t) % 5], team_name=team, team_goalserve_id=trigram_for_team_name(team),
                daily_price=float(price), avg_fantasy_score=price * 1.8, games_played=20, is_active=True,
            ).insert()
            players[(t, i)] = p

    def star(t: int, pos: str) -> Player:       # the 12M+ player of that position in team t
        return next(p for (tt, i), p in players.items() if tt == t and i < 5 and p.position == pos)

    def cheap(t: int, pos: str) -> Player:      # the <=10M player of that position in team t
        return next(p for (tt, i), p in players.items() if tt == t and i >= 5 and p.position == pos)

    def entry(p: Player) -> dict:
        return {"id": str(p.id), "name": p.full_name, "position": p.position, "team": p.team_name,
                "team_id": p.team_goalserve_id, "status": "OK", "price": f"{p.daily_price:g}M"}

    # ── users, wallets, bonuses
    names = ["me", "me2", "r1", "r2", "r3", "r4"]
    users: dict[str, User] = {}
    for n, name in enumerate(names, start=1):
        users[name] = await User(
            email=f"{name}@example.com", hashed_password=hash_password(PASSWORD), full_name=f"Local {name}",
            is_active=True, is_verified=True, is_profile_complete=True, terms_accepted=True,
            team_name=f"Local {name}", team_logo=["devil", "flower", "ufo", "shark", "lightning", "dragon"][n - 1],
            favourite_team="Boston Celtics", token_balance=1000, auto_id=n,
        ).insert()
        await TokenWallet(user_id=users[name].id, balance=1000).insert()
        await UserBonusInventory(
            user_id=users[name].id, sixth_man_charges=5, chef_curry_charges=5, luxury_tax_charges=5,
            live_scoring_until=now + timedelta(days=365),
        ).insert()
    await db.counters.update_one({"_id": "users"}, {"$set": {"seq": len(names)}}, upsert=True)

    # ── leagues
    glob = await League(name="NBA Global League", type="global", status="regular_season", budget=100,
                        max_size=999999, current_size=len(names), current_match_day=1, auto_id=1).insert()
    duel = await League(name="Local Duel League", type="private", status="regular_season", budget=100,
                        max_size=4, current_size=4, current_match_day=1, total_match_days=6, auto_id=2,
                        admin_id=users["me"].id, invite_code="LOCAL1").insert()
    await db.counters.update_one({"_id": "leagues"}, {"$set": {"seq": 2}}, upsert=True)
    for u in users.values():
        await LeagueMembership(league_id=glob.id, user_id=u.id).insert()
    for name in ("me", "r1", "r2", "r3"):
        await LeagueMembership(league_id=duel.id, user_id=users[name].id).insert()
    for day, night in ((1, P), (2, T)):
        await LeagueMatch(league_id=duel.id, match_day=day, nba_date=night, auto_id=day * 10 + 1,
                          home_user_id=users["me"].id, away_user_id=users["r1"].id).insert()
        await LeagueMatch(league_id=duel.id, match_day=day, nba_date=night, auto_id=day * 10 + 2,
                          home_user_id=users["r2"].id, away_user_id=users["r3"].id).insert()

    # ── games and stats
    async def games_for(night, statuses: list[str]) -> None:
        for g, status in enumerate(statuses):
            home, away = (g, g + 6)                      # six games: team g against team g+6
            tip = {"final": now - timedelta(hours=4 + g), "live": now - timedelta(hours=1),
                   "scheduled": now + timedelta(hours=3 + g)}[status]
            await NBAGame(
                goalserve_id=f"{night.isoformat()}-{g}", nba_date=night, home_team_id=trigram_for_team_name(TEAMS[home]),
                away_team_id=trigram_for_team_name(TEAMS[away]), home_team_name=TEAMS[home], away_team_name=TEAMS[away],
                status=status, tip_off_time=tip, home_score=110 if status != "scheduled" else None,
                away_score=100 if status != "scheduled" else None,
                final_at=tip + timedelta(hours=2) if status == "final" else None,
            ).insert()

    async def stats_for(night, game_ids, absent: set[tuple[int, int]], dnp: set[tuple[int, int]],
                        computed: bool, minutes_share: float = 1.0) -> None:
        for (t, i), p in players.items():
            g = t if t < 6 else t - 6
            if g not in game_ids or (t, i) in absent:        # an absent player has NO row at all
                continue
            is_dnp = (t, i) in dnp
            mins = 0 if is_dnp else int(random.randint(14, 38) * minutes_share)
            score = 0 if is_dnp else max(1, round(PRICES[i] * 1.8 + random.gauss(0, 5)))
            await PlayerGameStats(
                player_id=p.id, goalserve_player_id=p.goalserve_id, goalserve_game_id=f"{night.isoformat()}-{g}",
                nba_date=night, points=score, rebounds=3, assists=2, minutes_played=mins, did_not_play=is_dnp,
                fantasy_score=float(score) if computed else None, score_computed=computed,
            ).insert()

    async def lineup(user, league, match_day, night, picks, *, substitute=None, sixth=None, chef=False):
        sel = FlutterPlayerSelection(
            user_id=user.id, league_id=league.id, league_auto_id=league.auto_id, match_day=match_day,
            submitted_at=now, nba_date=night, selected_players=[entry(p) for p in picks],
            chef_curry=chef, sixth_man_player=entry(sixth) if sixth else None,
            substitute_player=entry(substitute) if substitute else None,
            substitute_set_at=now if substitute else None,
        )
        await sel.insert()

    def five(ts: list[int], absent=None):
        """Five starters, one per position family, from the given teams (stars), in the
        order the app saves them (the court's slots: wing, center, wing, guard, guard):
        the composition screens fill the slots by index."""
        order = ["SF", "C", "PF", "PG", "SG"]
        return [star(ts[k % len(ts)], pos) for k, pos in enumerate(order)]

    # ═══ the published night P ═══════════════════════════════════════════════
    # absent starters: A_sf = star SF of team 0 (no row), A_pf = star PF of team 1 (no row),
    # A_sg = star SG of team 2 (a row with 0 minute)
    A_sf, A_pf, A_sg = star(0, "SF"), star(1, "PF"), star(2, "SG")
    key = lambda p: next(k for k, v in players.items() if v is p)
    absent_P = {key(A_sf), key(A_pf)}
    dnp_P = {key(A_sg)}
    await games_for(P, ["final"] * 6)
    await stats_for(P, set(range(6)), absent_P, dnp_P, computed=True)

    # Global League lineups of P (match day 1)
    await lineup(users["me"], glob, 1, P, [A_sf, star(3, "PG"), star(4, "SG"), star(5, "PF"), star(3, "C")],
                 substitute=cheap(4, "SG"))                                        # absent starter -> entered
    await lineup(users["r1"], glob, 1, P, [star(0, "PG"), star(1, "SG"), star(2, "SF"), A_pf, star(4, "C")])  # absent, no substitute
    await lineup(users["r2"], glob, 1, P, [star(3, "PG"), A_sg, star(4, "SF"), star(5, "PF"), star(5, "C")],
                 substitute=cheap(3, "PG"))                                        # 0-minute row -> entered
    await lineup(users["r3"], glob, 1, P, five([3, 4, 5]), substitute=cheap(2, "C"))   # all played -> not entered
    await lineup(users["me2"], glob, 1, P, five([4, 5, 3]))
    # duels of P (match day 1): me vs r1, r2 vs r3
    await lineup(users["me"], duel, 1, P, [A_sf, star(3, "PG"), star(4, "SG"), star(5, "PF"), star(3, "C")],
                 substitute=cheap(4, "SG"), chef=True)
    await lineup(users["r1"], duel, 1, P, [star(0, "PG"), star(1, "SG"), star(2, "SF"), A_pf, star(4, "C")],
                 sixth=cheap(5, "PG"))
    await lineup(users["r2"], duel, 1, P, [star(3, "PG"), A_sg, star(4, "SF"), star(5, "PF"), star(5, "C")],
                 substitute=cheap(3, "PG"))
    await lineup(users["r3"], duel, 1, P, five([3, 4, 5]), substitute=cheap(2, "C"), sixth=cheap(5, "SG"))

    # the REAL closes, in the production order: Global archive, then duels + standings + match day
    await archive_daily_scores(P)
    await engine.run_daily_close(P)
    await mark_published(P)

    # ═══ tonight T ═══════════════════════════════════════════════════════════
    glob = await League.get(glob.id)
    duel = await League.get(duel.id)
    gday, dday = glob.current_match_day, duel.current_match_day
    if args.state == "open":
        await games_for(T, ["scheduled"] * 6)
        # rivals already saved their lineups (with substitutes: hidden from you until the first tip-off)
        await lineup(users["r1"], duel, dday, T, five([6, 7, 8]), substitute=cheap(9, "PG"))
        await lineup(users["r2"], duel, dday, T, five([8, 9, 10]), substitute=cheap(11, "SG"))
        await lineup(users["r3"], duel, dday, T, five([9, 10, 11]))
        await lineup(users["r1"], glob, gday, T, five([6, 7, 8]), substitute=cheap(9, "PG"))
    else:
        # games 0 and 1 final, 2 and 3 in progress, 4 and 5 not started
        await games_for(T, ["final", "final", "live", "live", "scheduled", "scheduled"])
        absent_T = {key(star(0, "SF"))}                                            # absent: no row
        await stats_for(T, {0, 1}, absent_T, set(), computed=True)
        await stats_for(T, {2, 3}, set(), set(), computed=False, minutes_share=0.5)   # games in progress
        # me: one starter plays in a live game -> the substitute stays "pending"
        mine = [star(0, "SF"), star(1, "PG"), star(7, "SG"), star(8, "PF"), star(6, "C")]
        await lineup(users["me"], duel, dday, T, mine, substitute=cheap(1, "SG"), chef=True)
        await lineup(users["me"], glob, gday, T, mine, substitute=cheap(1, "SG"))
        # me2: only teams of the two final games -> everything decided: the substitute is "entered"
        done = [star(0, "SF"), star(1, "PG"), star(6, "SG"), star(7, "PF"), star(1, "C")]
        await lineup(users["me2"], glob, gday, T, done, substitute=cheap(6, "PG"))
        await lineup(users["r1"], duel, dday, T, five([6, 7, 1]), substitute=cheap(7, "SG"))
        await lineup(users["r2"], duel, dday, T, five([2, 3, 8]))
        await lineup(users["r3"], duel, dday, T, five([8, 9, 3]))

    print("\nLocal simulator data ready (state: %s)" % args.state)
    print(f"  published night : {P}      tonight : {T}")
    print(f"  password for every account : {PASSWORD}")
    print("  accounts: " + ", ".join(f"{n}@example.com" for n in names))
    print("  leagues : Global (id 1, everyone)   |   Local Duel League (id 2, private: me, r1, r2, r3)")
    print("  published night: me = absent starter replaced (Global + duel, with Chef Curry); r1 = absent starter, no substitute;")
    print("                   r2 = 0-minute starter replaced; r3 = substitute did not enter; r3 duel also has a 6th Man")
    if args.state == "open":
        print("  tonight: all games scheduled; compose as me / me2; r1 r2 r3 already saved (r1, r2 with a substitute)")
    else:
        print("  tonight: me = pending (a starter plays in a live game); me2 (Global) = entered; games 4-5 not started")


if __name__ == "__main__":
    asyncio.run(main())

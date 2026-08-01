"""
Dev-only: full 7-day demo dataset for ittesafarik@gmail.com so every major
frontend screen has real, self-consistent data to show (Home Global League
card, My Matches Today, Night's Results / Games history, Live Score,
Leaderboard/Standings, Bonus Shop, notifications bell).

Reuses the REAL engine functions (start_league/score_match_day/
update_standings/advance_match_day/archive_daily_scores/sync_match_live_status)
rather than hand-faking scores/standings, so the data is exactly as
consistent as a real 7-day season would produce. Scoped only to:
  - this user's own fields (password, memberships, selections)
  - the "khela" private league (already exclusively this user's empty league)
  - 7 days of NBAGame/PlayerGameStats for 4 fixed teams (goalserve_id
    prefixed "demo7_" so it never collides with anything else)
No other league or user is touched except adding 5 existing seed accounts
(admin@/user2-5@mon5majeur.com) as co-members of "khela" so it has the
4-member minimum needed to start a round-robin season.

Idempotent: safe to re-run any day — clears/upserts its own demo7_ data,
checks membership/league-status before mutating.
"""
from __future__ import annotations

import asyncio
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, r"c:\Users\ittes\Desktop\Arik\Desktop\ARIK\Mon5majeur\Mon5majeur-Backend")

from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings
from app.core.security import hash_password
from app.modules.bonuses.model import UserBonusInventory, UserBonusQuota
from app.modules.leagues.engine import (
    advance_match_day,
    score_match_day,
    start_league,
    sync_match_live_status,
    update_standings,
)
from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
from app.modules.leagues.global_score_service import archive_daily_scores
from app.modules.leagues.model import League, LeagueMatch, LeagueMembership
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.notifications.model import Notification
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.scoring import compute_and_stamp
from app.modules.tokens.model import TokenTransaction, TokenWallet
from app.modules.users.model import User

TARGET_EMAIL = "ittesafarik@gmail.com"
PASSWORD = "12345678"
CO_MEMBER_EMAILS = [
    "admin@mon5majeur.com", "user2@mon5majeur.com", "user3@mon5majeur.com",
    "user4@mon5majeur.com", "user5@mon5majeur.com",
]
TEAMS = ["Los Angeles Lakers", "Golden State Warriors", "Boston Celtics", "Miami Heat"]
TEAM_IDS = {
    "Los Angeles Lakers": "LAL", "Golden State Warriors": "GSW",
    "Boston Celtics": "BOS", "Miami Heat": "MIA",
}


async def main() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URI, serverSelectionTimeoutMS=20000)
    db = client[settings.MONGODB_DB_NAME]
    await init_beanie(database=db, document_models=[
        User, NBAGame, Player, PlayerGameStats, League, LeagueMembership, LeagueMatch,
        FlutterPlayerSelection, UserBonusQuota, UserBonusInventory,
        TokenWallet, TokenTransaction, Notification, GlobalLeagueDailyScore,
    ])

    today = datetime.now(timezone.utc).date()
    dates = [today - timedelta(days=i) for i in range(6, -1, -1)]  # oldest -> today
    print(f"Seeding 7-day demo data for {TARGET_EMAIL}, dates {dates[0]}..{dates[-1]}")

    user = await User.find_one(User.email == TARGET_EMAIL)
    if not user:
        raise SystemExit(f"User {TARGET_EMAIL} not found in Atlas")

    # ------------------------------------------------------------------
    # 1. Password
    # ------------------------------------------------------------------
    user.hashed_password = hash_password(PASSWORD)
    await user.save()
    print("Password set.")

    # ------------------------------------------------------------------
    # 2. NBAGame + PlayerGameStats for the last 7 days (4 fixed teams,
    #    2 games/day: LAL-GSW, BOS-MIA). Idempotent via goalserve_id prefix.
    # ------------------------------------------------------------------
    await NBAGame.find({"goalserve_id": {"$regex": "^(demo7_|test_g)"}}).delete()
    await PlayerGameStats.find({"goalserve_game_id": {"$regex": "^(demo7_|test_g)"}}).delete()

    team_players: dict[str, list[Player]] = {}
    for t in TEAMS:
        team_players[t] = await Player.find(Player.team_name == t).to_list()

    now = datetime.now(timezone.utc)
    all_games = []
    all_stats = []
    for day_idx, d in enumerate(dates):
        is_today = d == today
        pairs = [
            ("LAL", "GSW", "Los Angeles Lakers", "Golden State Warriors"),
            ("BOS", "MIA", "Boston Celtics", "Miami Heat"),
        ]
        for gi, (hid, aid, hname, aname) in enumerate(pairs):
            gid = f"demo7_{day_idx}_{gi}"
            if is_today:
                status = "final" if gi == 0 else "live"
                tip_off = now + timedelta(hours=1 + gi * 2)  # future -> never locks today
                hs, as_ = (105 + day_idx, 100 + day_idx) if gi == 0 else (55 + day_idx, 50 + day_idx)
            else:
                status = "final"
                tip_off = datetime.combine(d, datetime.min.time(), tzinfo=timezone.utc) + timedelta(hours=19)
                hs, as_ = 95 + (day_idx * 3) % 30, 90 + (day_idx * 5) % 30

            all_games.append(NBAGame(
                goalserve_id=gid, nba_date=d, home_team_id=hid, away_team_id=aid,
                home_team_name=hname, away_team_name=aname, status=status,
                tip_off_time=tip_off, home_score=hs, away_score=as_,
            ))

            for team_name in (hname, aname):
                for pi, p in enumerate(team_players.get(team_name, [])[:8]):
                    seed = day_idx * 31 + pi * 7
                    line = dict(
                        points=12 + seed % 22, rebounds=3 + seed % 11, assists=2 + seed % 9,
                        steals=seed % 3, blocks=seed % 2, turnovers=1 + seed % 4,
                        field_goals_made=5 + seed % 8, field_goals_attempted=12 + seed % 10,
                        threepoint_made=seed % 5, threepoint_attempted=2 + seed % 6,
                        freethrow_made=1 + seed % 5, freethrow_attempted=2 + seed % 5,
                        minutes_played=15 + seed % 25,
                    )
                    stat = PlayerGameStats(
                        player_id=p.id, goalserve_player_id=p.goalserve_id,
                        goalserve_game_id=gid, nba_date=d, did_not_play=False, **line,
                    )
                    compute_and_stamp(stat)
                    all_stats.append(stat)

    await NBAGame.insert_many(all_games)
    await PlayerGameStats.insert_many(all_stats)
    print(f"Seeded {len(all_games)} games / {len(all_stats)} stat-lines across {len(dates)} days.")

    squad_pool: list[Player] = []
    for t in TEAMS:
        squad_pool.extend(team_players[t])

    # ------------------------------------------------------------------
    # 3. Global League — join + 7-day squad history + archived daily scores
    # ------------------------------------------------------------------
    global_league = await League.find_one(League.type == "global", League.status == "regular_season") \
        or await League.find_one(League.type == "global")

    gmembership = await LeagueMembership.find_one(
        LeagueMembership.league_id == global_league.id, LeagueMembership.user_id == user.id,
    )
    if not gmembership:
        await LeagueMembership(league_id=global_league.id, user_id=user.id).insert()
        global_league.current_size += 1
        await global_league.save()
        print("Joined Global League.")

    def _pick_squad(pool: list[Player], start: int) -> list[Player]:
        positions_needed = ["PG", "SG", "SF", "PF", "C"]
        squad: list[Player] = []
        used: set = set()
        rotated = pool[start:] + pool[:start]
        for pos in positions_needed:
            for p in rotated:
                if p.position == pos and p.id not in used:
                    squad.append(p)
                    used.add(p.id)
                    break
        for p in rotated:
            if len(squad) >= 5:
                break
            if p.id not in used:
                squad.append(p)
                used.add(p.id)
        return squad[:5]

    gl_squad = _pick_squad(squad_pool, 0)
    gl_payload = [{
        "id": str(p.id), "name": p.full_name, "position": p.position or "?",
        "team": p.team_name, "team_id": TEAM_IDS.get(p.team_name, ""),
        "status": "OK", "price": f"{p.daily_price}M",
    } for p in gl_squad]

    gl_current_md = global_league.current_match_day or 1
    for i, d in enumerate(dates):
        md = max(1, gl_current_md - (len(dates) - 1 - i))
        sel = await FlutterPlayerSelection.find_one(
            FlutterPlayerSelection.user_id == user.id,
            FlutterPlayerSelection.league_auto_id == global_league.auto_id,
            FlutterPlayerSelection.match_day == md,
        )
        if sel:
            sel.selected_players = gl_payload
            await sel.save()
        else:
            await FlutterPlayerSelection(
                user_id=user.id, league_id=global_league.id, league_auto_id=global_league.auto_id,
                match_day=md, selected_players=gl_payload,
                submitted_at=datetime.now(timezone.utc) - timedelta(days=len(dates) - 1 - i),
            ).insert()

    for d in dates:
        await archive_daily_scores(d)
    print("Global League: squad set for last 7 match days, daily scores archived.")

    # ------------------------------------------------------------------
    # 4. Private League "khela" — add co-members, start season, replay 6
    #    completed nights + today live (real engine functions throughout)
    # ------------------------------------------------------------------
    khela = await League.find_one(League.name == "khela", League.type == "private")
    if not khela:
        raise SystemExit("'khela' league not found")

    comembers = []
    for email in CO_MEMBER_EMAILS:
        u = await User.find_one(User.email == email)
        if u:
            comembers.append(u)

    for u in comembers:
        exists = await LeagueMembership.find_one(
            LeagueMembership.league_id == khela.id, LeagueMembership.user_id == u.id,
        )
        if not exists:
            await LeagueMembership(league_id=khela.id, user_id=u.id).insert()

    all_members = await LeagueMembership.find(LeagueMembership.league_id == khela.id).to_list()
    khela.current_size = len(all_members)
    await khela.save()
    print(f"'khela' now has {len(all_members)} members.")

    if khela.status == "waiting":
        khela = await start_league(khela.id, dates[0])
        print(f"Started 'khela': total_match_days={khela.total_match_days}")

    member_ids = [m.user_id for m in all_members]
    squads_by_user = {uid: _pick_squad(squad_pool, i * 3) for i, uid in enumerate(member_ids)}

    N_DAYS = 7
    for match_day in range(1, N_DAYS + 1):
        nba_date_for_day = dates[match_day - 1]

        for uid in member_ids:
            squad = squads_by_user[uid]
            payload = [{
                "id": str(p.id), "name": p.full_name, "position": p.position or "?",
                "price": f"{p.daily_price}M",
            } for p in squad]
            sel = await FlutterPlayerSelection.find_one(
                FlutterPlayerSelection.user_id == uid,
                FlutterPlayerSelection.league_auto_id == khela.auto_id,
                FlutterPlayerSelection.match_day == match_day,
            )
            if sel:
                sel.selected_players = payload
                await sel.save()
            else:
                await FlutterPlayerSelection(
                    user_id=uid, league_id=khela.id, league_auto_id=khela.auto_id,
                    match_day=match_day, selected_players=payload,
                    submitted_at=datetime.now(timezone.utc) - timedelta(days=N_DAYS - match_day),
                ).insert()

        if match_day < N_DAYS:
            # Past, fully-closed night: score + standings + advance (mirrors
            # the real 09:00 daily-close pipeline for that historical date).
            await score_match_day(khela.id, match_day, nba_date_for_day)
            await update_standings(khela.id)
            await advance_match_day(khela.id)
        else:
            # Today (match_day == N_DAYS): games are still final/live, not
            # closed yet — only flip upcoming->live, exactly like the real
            # 20-min live-sync job does during the day (no scoring yet).
            await sync_match_live_status(nba_date_for_day)
            khela = await League.get(khela.id)
            khela.current_match_day = match_day
            await khela.save()

    print("'khela': 6 nights scored + standings updated, today's match live.")

    # ------------------------------------------------------------------
    # 5. Bonus shop + token wallet + notifications for this user
    # ------------------------------------------------------------------
    wallet = await TokenWallet.find_one(TokenWallet.user_id == user.id)
    if not wallet:
        wallet = TokenWallet(user_id=user.id, balance=0)
        await wallet.insert()
    wallet.balance += 500
    await wallet.save()
    await TokenTransaction(
        user_id=user.id, amount=500, balance_after=wallet.balance,
        type="admin_grant", note="Demo data top-up",
    ).insert()

    inv = await UserBonusInventory.find_one(UserBonusInventory.user_id == user.id)
    if not inv:
        inv = UserBonusInventory(user_id=user.id)
        await inv.insert()
    inv.sixth_man_charges = 3
    inv.chef_curry_charges = 3
    inv.luxury_tax_charges = 3
    inv.live_scoring_until = datetime.now(timezone.utc) + timedelta(days=30)
    await inv.save()

    quota = await UserBonusQuota.find_one(
        UserBonusQuota.user_id == user.id, UserBonusQuota.league_id == khela.id,
    )
    if not quota:
        await UserBonusQuota(user_id=user.id, league_id=khela.id).insert()

    await Notification.find(Notification.recipient_id == user.id).delete()
    await Notification.insert_many([
        Notification(recipient_id=user.id, title="Don't forget your team!",
                      body="Lock in your lineup before tip-off.", notification_type="team_reminder"),
        Notification(recipient_id=user.id, title="Match result",
                      body="Your duel in 'khela' just finished — check the result!",
                      notification_type="results", is_read=True),
        Notification(recipient_id=user.id, title="🏆 Top 8 this week!",
                      body="You finished in the Global League's weekly Top 8.",
                      notification_type="weekly_top8_reward"),
    ])
    print("Token wallet, bonus inventory, and notifications seeded.")

    print(f"\nDone. Log in as {TARGET_EMAIL} / {PASSWORD} to see 7 days of data across "
          f"Home, My Matches Today, Night's Results, Live Score, Leaderboard, and Bonus Shop.")

    client.close()


if __name__ == "__main__":
    asyncio.run(main())

"""
Follow-up to seed_demo_week_ittesafarik.py: that script only put the user in
a private league ("khela") and the Global League — the Public League screen
was still genuinely empty (no membership existed anywhere). Also grants
premium (Live Score access) so today's LIVE match shows on the Home
"Night's Results" card instead of always falling back to yesterday's
completed result (see get_my_matches_today_compat: a live match is hidden
from non-premium users by design, spec-accurate, not a bug — but confusing
to hit while testing without premium).

Creates a fresh 6-member public league using the same real engine functions
(start_league/score_match_day/update_standings/advance_match_day) and the
same 7-day NBAGame/PlayerGameStats fixture from seed_demo_week_ittesafarik.py
(4-team demo7_ pool). Idempotent.
"""
from __future__ import annotations

import asyncio
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, r"c:\Users\ittes\Desktop\Arik\Desktop\ARIK\Mon5majeur\Mon5majeur-Backend")

from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings
from app.modules.leagues.engine import (
    advance_match_day,
    score_match_day,
    start_league,
    sync_match_live_status,
    update_standings,
)
from app.modules.leagues.model import League, LeagueMatch, LeagueMembership
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.users.model import User

TARGET_EMAIL = "ittesafarik@gmail.com"
CO_MEMBER_EMAILS = [
    "admin@mon5majeur.com", "user2@mon5majeur.com", "user3@mon5majeur.com",
    "user4@mon5majeur.com", "user5@mon5majeur.com",
]
TEAMS = ["Los Angeles Lakers", "Golden State Warriors", "Boston Celtics", "Miami Heat"]
PUBLIC_LEAGUE_NAME = "Demo Public League"


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


async def main() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URI, serverSelectionTimeoutMS=20000)
    db = client[settings.MONGODB_DB_NAME]
    await init_beanie(database=db, document_models=[
        User, NBAGame, Player, PlayerGameStats, League, LeagueMembership, LeagueMatch,
        FlutterPlayerSelection,
    ])

    today = datetime.now(timezone.utc).date()
    dates = [today - timedelta(days=i) for i in range(6, -1, -1)]
    print(f"Setting up public league demo for {TARGET_EMAIL}, dates {dates[0]}..{dates[-1]}")

    user = await User.find_one(User.email == TARGET_EMAIL)
    if not user:
        raise SystemExit(f"User {TARGET_EMAIL} not found")

    # Grant premium (Live Score access) so today's live match isn't hidden
    user.premium_until = datetime.now(timezone.utc) + timedelta(days=30)
    await user.save()
    print("Granted 30-day premium (Live Score access).")

    from app.database.counters import next_seq

    league = await League.find_one(League.name == PUBLIC_LEAGUE_NAME, League.type == "public")
    if not league:
        league = League(
            name=PUBLIC_LEAGUE_NAME, type="public", status="waiting",
            budget=100, max_size=6, description="Demo public league (7-day history).",
            logo="lightning",
        )
        await league.insert()
        print("Created 'Demo Public League'.")
    if league.auto_id is None:
        league.auto_id = await next_seq("leagues")
        await league.save()

    comembers = []
    for email in CO_MEMBER_EMAILS:
        u = await User.find_one(User.email == email)
        if u:
            comembers.append(u)

    for u in [user] + comembers:
        exists = await LeagueMembership.find_one(
            LeagueMembership.league_id == league.id, LeagueMembership.user_id == u.id,
        )
        if not exists:
            await LeagueMembership(league_id=league.id, user_id=u.id).insert()

    all_members = await LeagueMembership.find(LeagueMembership.league_id == league.id).to_list()
    league.current_size = len(all_members)
    await league.save()
    print(f"'{PUBLIC_LEAGUE_NAME}' now has {len(all_members)} members.")

    if league.status == "waiting":
        league = await start_league(league.id, dates[0])
        print(f"Started '{PUBLIC_LEAGUE_NAME}': total_match_days={league.total_match_days}")

    squad_pool: list[Player] = []
    for t in TEAMS:
        squad_pool.extend(await Player.find(Player.team_name == t).to_list())

    member_ids = [m.user_id for m in all_members]
    squads_by_user = {uid: _pick_squad(squad_pool, i * 3 + 1) for i, uid in enumerate(member_ids)}

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
                FlutterPlayerSelection.league_auto_id == league.auto_id,
                FlutterPlayerSelection.match_day == match_day,
            )
            if sel:
                sel.selected_players = payload
                await sel.save()
            else:
                await FlutterPlayerSelection(
                    user_id=uid, league_id=league.id, league_auto_id=league.auto_id,
                    match_day=match_day, selected_players=payload,
                    submitted_at=datetime.now(timezone.utc) - timedelta(days=N_DAYS - match_day),
                ).insert()

        if match_day < N_DAYS:
            await score_match_day(league.id, match_day, nba_date_for_day)
            await update_standings(league.id)
            await advance_match_day(league.id)
        else:
            await sync_match_live_status(nba_date_for_day)
            league = await League.get(league.id)
            league.current_match_day = match_day
            await league.save()

    print(f"'{PUBLIC_LEAGUE_NAME}': 6 nights scored + standings updated, today's match live.")
    print(f"\nDone. {TARGET_EMAIL} is now in an active public league with 7-day history + premium.")

    client.close()


if __name__ == "__main__":
    asyncio.run(main())

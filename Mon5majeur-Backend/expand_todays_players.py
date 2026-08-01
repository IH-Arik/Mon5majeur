"""
Dev-only follow-up to seed_demo_week_ittesafarik.py: the Players Today picker
(GET /api/players-today/) filters strictly by Player.team_goalserve_id
matching today's NBAGame home/away team_id — and only matches teams whose
players carry the REAL Goalserve numeric team ID (e.g. "1610612747" for the
Lakers). The original 4-team demo7_ dataset used the old 3-letter mock IDs
("LAL"/"GSW"/etc.) which only match ~1 legacy mock player per team, so the
picker showed almost nothing despite 600+ real synced players existing.

This replaces *only today's* games/stats (keeps the past 6 demo7_ days
untouched) with 6 games across 12 teams, using each team's real numeric
team_goalserve_id, covering ~200 real roster players for a properly-sized
team-builder pool. Idempotent — safe to re-run.
"""
from __future__ import annotations

import asyncio
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, r"c:\Users\ittes\Desktop\Arik\Desktop\ARIK\Mon5majeur\Mon5majeur-Backend")

from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.scoring import compute_and_stamp

# (home_id, away_id, home_name, away_name, status, hours_from_now, home_score, away_score)
GAMES_TODAY = [
    ("1610612747", "1610612744", "Los Angeles Lakers", "Golden State Warriors", "final", 1, 111, 106),
    ("1610612738", "1610612748", "Boston Celtics", "Miami Heat", "live", 3, 58, 52),
    ("1610612743", "1610612742", "Denver Nuggets", "Dallas Mavericks", "final", 1, 118, 109),
    ("1610612756", "1610612749", "Phoenix Suns", "Milwaukee Bucks", "live", 2, 61, 57),
    ("1610612755", "1610612760", "Philadelphia 76ers", "Oklahoma City Thunder", "scheduled", 5, None, None),
    ("1610612750", "1610612752", "Minnesota Timberwolves", "New York Knicks", "scheduled", 6, None, None),
]


async def main() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URI, serverSelectionTimeoutMS=20000)
    db = client[settings.MONGODB_DB_NAME]
    await init_beanie(database=db, document_models=[NBAGame, Player, PlayerGameStats])

    today = datetime.now(timezone.utc).date()
    print(f"Expanding today's ({today}) player pool across {len(GAMES_TODAY)} games / 12 teams")

    # Clear only today's demo7*-prefixed games/stats (leaves the 6 historical days alone)
    todays_games = await NBAGame.find(NBAGame.nba_date == today).to_list()
    old_today = [g for g in todays_games if g.goalserve_id.startswith("demo7")]
    if old_today:
        old_ids = [g.goalserve_id for g in old_today]
        for g in old_today:
            await g.delete()
        await PlayerGameStats.find({"goalserve_game_id": {"$in": old_ids}}).delete()
        print(f"Cleared {len(old_today)} previous today-only demo game(s).")

    now = datetime.now(timezone.utc)
    all_games = []
    all_stats = []
    for gi, (hid, aid, hname, aname, status, hours, hs, as_) in enumerate(GAMES_TODAY):
        gid = f"demo7today_{gi}"
        all_games.append(NBAGame(
            goalserve_id=gid, nba_date=today, home_team_id=hid, away_team_id=aid,
            home_team_name=hname, away_team_name=aname, status=status,
            tip_off_time=now + timedelta(hours=hours), home_score=hs, away_score=as_,
        ))

        for team_name, team_gid in ((hname, hid), (aname, aid)):
            players = await Player.find(
                Player.team_name == team_name, Player.team_goalserve_id == team_gid,
            ).to_list()
            for pi, p in enumerate(players):
                seed = gi * 17 + pi * 5
                line = dict(
                    points=10 + seed % 25, rebounds=2 + seed % 12, assists=1 + seed % 9,
                    steals=seed % 3, blocks=seed % 2, turnovers=1 + seed % 4,
                    field_goals_made=4 + seed % 9, field_goals_attempted=10 + seed % 12,
                    threepoint_made=seed % 5, threepoint_attempted=1 + seed % 6,
                    freethrow_made=seed % 5, freethrow_attempted=1 + seed % 5,
                    minutes_played=12 + seed % 28,
                )
                stat = PlayerGameStats(
                    player_id=p.id, goalserve_player_id=p.goalserve_id,
                    goalserve_game_id=gid, nba_date=today, did_not_play=False, **line,
                )
                compute_and_stamp(stat)
                all_stats.append(stat)

    await NBAGame.insert_many(all_games)
    await PlayerGameStats.insert_many(all_stats)
    print(f"Inserted {len(all_games)} games and {len(all_stats)} player stat-lines for today.")

    client.close()


if __name__ == "__main__":
    asyncio.run(main())

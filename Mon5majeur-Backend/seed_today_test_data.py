"""
Dev-only helper: NBA is in real off-season right now (last real season ended
mid-June 2026, next one starts October) so Goalserve genuinely has zero games
for "today" — Games Today / My Matches Today / Players Today / Global League
all come back empty as a correct reflection of reality, not a bug.

This script seeds fresh NBAGame + PlayerGameStats rows dated to the actual
current date (reusing existing Player docs already in Atlas — no duplicate
players created) so the app's "today" screens have something to show while
testing/demoing during the off-season. It also re-dates the 3 existing
"Active Private League" (admin@/user2-6@mon5majeur.com) current-match-day
LeagueMatch rows from their frozen June 13 seed date to today, so
My Matches Today has something to show for those seed accounts too.

Safe to re-run: it's idempotent for today's date (upserts by goalserve_id /
unique index), and only ever touches "today"-scoped data plus that one
league's current match day — no other collections are modified.
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings
from app.modules.leagues.model import League, LeagueMatch
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.scoring import compute_and_stamp


async def main() -> None:
    client = AsyncIOMotorClient(settings.MONGODB_URI, serverSelectionTimeoutMS=20000)
    db = client[settings.MONGODB_DB_NAME]
    await init_beanie(
        database=db,
        document_models=[NBAGame, Player, PlayerGameStats, League, LeagueMatch],
    )

    today = datetime.now(timezone.utc).date()
    print(f"Seeding test NBA data for today = {today}")

    # ------------------------------------------------------------------
    # 1. Clear any previous test games/stats for today (idempotent re-run)
    # ------------------------------------------------------------------
    old_games = await NBAGame.find(NBAGame.nba_date == today).to_list()
    old_ids = [g.goalserve_id for g in old_games]
    if old_ids:
        await NBAGame.find(NBAGame.nba_date == today).delete()
        await PlayerGameStats.find(PlayerGameStats.nba_date == today).delete()
        print(f"Cleared {len(old_ids)} previous test game(s) for {today}")

    # ------------------------------------------------------------------
    # 2. Games for today, in different states (scheduled / live / final)
    # ------------------------------------------------------------------
    # NOTE: tip_off_time deliberately kept in the FUTURE for every game, even
    # the "final"/"live" ones — the lock check (get_global_selection /
    # save_player_selection) locks lineup submission for the whole night once
    # the EARLIEST game of the day has tipped off. A past tip-off here would
    # 403 every save_selection call for the rest of the day, which defeats
    # the point of a test fixture meant to be usable all day while testing.
    now = datetime.now(timezone.utc)
    games_spec = [
        # (id, home, away, home_id, away_id, status, home_score, away_score, tip_off_offset_hours)
        ("test_g1", "Los Angeles Lakers", "Golden State Warriors", "LAL", "GSW", "final", 112, 108, 1),
        ("test_g2", "Boston Celtics", "Miami Heat", "BOS", "MIA", "final", 101, 97, 2),
        ("test_g3", "Denver Nuggets", "Dallas Mavericks", "DEN", "DAL", "live", 58, 52, 3),
        ("test_g4", "Milwaukee Bucks", "Phoenix Suns", "MIL", "PHX", "scheduled", None, None, 5),
    ]

    games = []
    for gid, home, away, home_id, away_id, status, hs, as_, hours in games_spec:
        games.append(NBAGame(
            goalserve_id=gid,
            nba_date=today,
            home_team_id=home_id,
            away_team_id=away_id,
            home_team_name=home,
            away_team_name=away,
            status=status,
            tip_off_time=now + timedelta(hours=hours),
            home_score=hs,
            away_score=as_,
        ))
    await NBAGame.insert_many(games)
    print(f"Inserted {len(games)} NBAGame docs for {today}")

    # ------------------------------------------------------------------
    # 3. Box-score stats for players on the final/live games (existing
    #    Player docs only — matched by team_name, no new players created)
    # ------------------------------------------------------------------
    teams_with_stats = {
        "test_g1": ("Los Angeles Lakers", "Golden State Warriors"),
        "test_g2": ("Boston Celtics", "Miami Heat"),
        "test_g3": ("Denver Nuggets", "Dallas Mavericks"),
    }

    stat_count = 0
    for game_id, (home_team, away_team) in teams_with_stats.items():
        players = await Player.find(
            {"team_name": {"$in": [home_team, away_team]}}
        ).to_list()
        for i, p in enumerate(players[:10]):  # cap per game, avoids bloating every bench player
            line = dict(
                points=18 + (i * 3) % 20,
                rebounds=4 + (i * 2) % 10,
                assists=3 + (i * 2) % 8,
                steals=(i % 3),
                blocks=(i % 2),
                turnovers=1 + (i % 3),
                field_goals_made=7 + (i % 6),
                field_goals_attempted=14 + (i % 8),
                threepoint_made=(i % 4),
                threepoint_attempted=2 + (i % 5),
                freethrow_made=2 + (i % 4),
                freethrow_attempted=3 + (i % 4),
                minutes_played=20 + (i * 3) % 20,
            )
            stat = PlayerGameStats(
                player_id=p.id,
                goalserve_player_id=p.goalserve_id,
                goalserve_game_id=game_id,
                nba_date=today,
                did_not_play=False,
                **line,
            )
            compute_and_stamp(stat)
            await stat.insert()
            stat_count += 1

    print(f"Inserted {stat_count} PlayerGameStats rows")

    # ------------------------------------------------------------------
    # 4. Re-date "Active Private League" (admin@/user2-6@mon5majeur.com)
    #    current-match-day matches from their frozen seed date to today,
    #    with a spread of statuses so My Matches Today shows all 3 states.
    # ------------------------------------------------------------------
    league = await League.find_one(League.name == "Active Private League")
    if league:
        matches = await LeagueMatch.find(
            LeagueMatch.league_id == league.id,
            LeagueMatch.match_day == league.current_match_day,
        ).to_list()

        statuses = ["completed", "live", "upcoming"]
        for i, m in enumerate(matches):
            m.nba_date = today
            m.status = statuses[i % len(statuses)]
            if m.status == "completed":
                m.home_score, m.away_score = 245.5, 231.0
                m.winner_id = m.home_user_id
            elif m.status == "live":
                m.home_score, m.away_score = 118.0, 102.5
            else:
                m.home_score, m.away_score = None, None
            await m.save()
        print(f"Re-dated {len(matches)} LeagueMatch row(s) in '{league.name}' to {today} "
              f"(statuses: {statuses[:len(matches)]})")
    else:
        print("WARNING: 'Active Private League' not found — skipped My Matches Today fixture")

    print("\nDone. Test accounts for My Matches Today: admin@mon5majeur.com / user2-6@mon5majeur.com "
          "(password: password123, per seed_all_data.py)")
    print("Games Today / Players Today / Global League should now show data for ANY logged-in user.")

    client.close()


if __name__ == "__main__":
    asyncio.run(main())

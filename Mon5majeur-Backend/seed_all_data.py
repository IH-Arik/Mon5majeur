import asyncio
import random
from datetime import date, datetime, timedelta, timezone
from beanie import PydanticObjectId
from app.database.session import init_db
from app.core.security import hash_password
from app.database.counters import next_seq

# Import models
from app.modules.users.model import User
from app.modules.roles.model import Role
from app.modules.permissions.model import Permission
from app.modules.players.model import Player, PlayerGameStats, NBAGame
from app.modules.tokens.model import TokenWallet, TokenTransaction
from app.modules.leagues.model import League, LeagueMembership, LeagueMatch
from app.modules.leagues.playoff_model import PlayoffSeries
from app.modules.lineups.model import LineupSlot, LineupSubmission
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.bonuses.model import UserBonusQuota, UserBonusInventory
from app.modules.files.model import UploadedFile
from app.modules.competitions.model import Competition, CompetitionEntry
from app.modules.fantasy_teams.model import FantasyTeam
from app.modules.auth.model import OTPToken, RefreshToken
from app.modules.notifications.model import Notification

from app.modules.players.scoring import compute_fantasy_score

async def clean_database(db):
    print("Clearing collections...")
    await User.find_all().delete()
    await Role.find_all().delete()
    await Permission.find_all().delete()
    await Player.find_all().delete()
    await PlayerGameStats.find_all().delete()
    await NBAGame.find_all().delete()
    await TokenWallet.find_all().delete()
    await TokenTransaction.find_all().delete()
    await League.find_all().delete()
    await LeagueMembership.find_all().delete()
    await LeagueMatch.find_all().delete()
    await PlayoffSeries.find_all().delete()
    await LineupSlot.find_all().delete()
    await LineupSubmission.find_all().delete()
    await FlutterPlayerSelection.find_all().delete()
    await UserBonusQuota.find_all().delete()
    await UserBonusInventory.find_all().delete()
    await UploadedFile.find_all().delete()
    await Competition.find_all().delete()
    await CompetitionEntry.find_all().delete()
    await FantasyTeam.find_all().delete()
    await OTPToken.find_all().delete()
    await RefreshToken.find_all().delete()
    await Notification.find_all().delete()

    print("Resetting auto-increment counters...")
    await db.counters.delete_many({})

MOCK_PLAYERS_RAW = [
    {"goalserve_id": "1001", "first_name": "LeBron", "last_name": "James", "position": "SF", "team_name": "Los Angeles Lakers", "price": 10.5},
    {"goalserve_id": "1002", "first_name": "Stephen", "last_name": "Curry", "position": "PG", "team_name": "Golden State Warriors", "price": 9.8},
    {"goalserve_id": "1003", "first_name": "Giannis", "last_name": "Antetokounmpo", "position": "PF", "team_name": "Milwaukee Bucks", "price": 11.2},
    {"goalserve_id": "1004", "first_name": "Nikola", "last_name": "Jokic", "position": "C", "team_name": "Denver Nuggets", "price": 12.0},
    {"goalserve_id": "1005", "first_name": "Luka", "last_name": "Doncic", "position": "PG", "team_name": "Dallas Mavericks", "price": 11.5},
    {"goalserve_id": "1006", "first_name": "Kevin", "last_name": "Durant", "position": "PF", "team_name": "Phoenix Suns", "price": 9.5},
    {"goalserve_id": "1007", "first_name": "Joel", "last_name": "Embiid", "position": "C", "team_name": "Philadelphia 76ers", "price": 10.8},
    {"goalserve_id": "1008", "first_name": "Jayson", "last_name": "Tatum", "position": "SF", "team_name": "Boston Celtics", "price": 9.2},
    {"goalserve_id": "1009", "first_name": "Anthony", "last_name": "Edwards", "position": "SG", "team_name": "Minnesota Timberwolves", "price": 8.5},
    {"goalserve_id": "1010", "first_name": "Shai", "last_name": "Gilgeous-Alexander", "position": "PG", "team_name": "Oklahoma City Thunder", "price": 10.2},
    {"goalserve_id": "1011", "first_name": "Devin", "last_name": "Booker", "position": "SG", "team_name": "Phoenix Suns", "price": 8.7},
    {"goalserve_id": "1012", "first_name": "Jimmy", "last_name": "Butler", "position": "SF", "team_name": "Miami Heat", "price": 8.0},
    {"goalserve_id": "1013", "first_name": "Bam", "last_name": "Adebayo", "position": "C", "team_name": "Miami Heat", "price": 8.3},
    {"goalserve_id": "1014", "first_name": "Damian", "last_name": "Lillard", "position": "PG", "team_name": "Milwaukee Bucks", "price": 8.9},
    {"goalserve_id": "1015", "first_name": "Kyrie", "last_name": "Irving", "position": "SG", "team_name": "Dallas Mavericks", "price": 8.8},
]

def _round_robin_schedule(user_ids):
    players = list(user_ids)
    n = len(players)
    if n % 2 != 0:
        players.append(None)
        n += 1

    aller = []
    for _ in range(n - 1):
        pairings = [(players[i], players[n - 1 - i]) for i in range(n // 2) if players[i] is not None and players[n - 1 - i] is not None]
        aller.append(pairings)
        players = [players[0]] + [players[-1]] + players[1:-1]

    retour = [[(away, home) for home, away in round_] for round_ in aller]
    return aller + retour

async def main():
    print("Initializing Beanie and MongoDB connection...")
    await init_db()
    db = League.get_motor_collection().database

    # Clear old data
    await clean_database(db)

    print("Seeding Players...")
    players = []
    for p in MOCK_PLAYERS_RAW:
        player = Player(
            goalserve_id=p["goalserve_id"],
            first_name=p["first_name"],
            last_name=p["last_name"],
            full_name=f"{p['first_name']} {p['last_name']}",
            position=p["position"],
            team_name=p["team_name"],
            daily_price=p["price"],
            avg_fantasy_score=random.randint(25, 50),
            games_played=random.randint(5, 20),
            is_active=True
        )
        await player.insert()
        players.append(player)
    print(f"Seeded {len(players)} players.")

    print("Seeding Users...")
    hashed_pw = hash_password("password123")
    users = []
    wallets = []
    transactions = []
    inventories = []
    
    # 15 users
    for i in range(1, 16):
        is_admin = (i == 1)
        email = "admin@mon5majeur.com" if is_admin else f"user{i}@mon5majeur.com"
        full_name = "Admin User" if is_admin else f"Test User {i}"
        team_name = f"Dunk Stars {i}"
        team_logo = ["devil", "flower", "ufo", "shark", "lightning", "dragon"][(i - 1) % 6]
        
        user = User(
            email=email,
            hashed_password=hashed_pw,
            full_name=full_name,
            is_active=True,
            is_superuser=is_admin,
            is_verified=True,
            is_profile_complete=True,
            team_name=team_name,
            team_logo=team_logo,
            favourite_team="Boston Celtics",
            token_balance=1000,
            auto_id=i
        )
        await user.insert()
        users.append(user)

    # Now create associated documents for each user
    for user in users:
        # Seed TokenWallet
        wallets.append(TokenWallet(user_id=user.id, balance=1000))

        # Seed initial TokenTransaction
        transactions.append(TokenTransaction(
            user_id=user.id,
            amount=1000,
            balance_after=1000,
            type="admin_grant",
            note="Initial seed tokens"
        ))

        # Seed UserBonusInventory
        inventories.append(UserBonusInventory(
            user_id=user.id,
            sixth_man_charges=5,
            chef_curry_charges=5,
            luxury_tax_charges=5,
            live_scoring_until=datetime.now(timezone.utc) + timedelta(days=365),
            stop_pub_until=datetime.now(timezone.utc) + timedelta(days=365)
        ))

    await TokenWallet.insert_many(wallets)
    await TokenTransaction.insert_many(transactions)
    await UserBonusInventory.insert_many(inventories)

    # Sync user auto-increment counter
    await db.counters.update_one({"_id": "users"}, {"$set": {"seq": 15}}, upsert=True)
    print(f"Seeded {len(users)} users, wallets, and bonus inventories.")

    # Seeding NBA games (yesterday, today, tomorrow)
    yesterday = date.today() - timedelta(days=1)
    today = date.today()
    tomorrow = date.today() + timedelta(days=1)

    print("Seeding NBA Games...")
    nba_games = [
        NBAGame(goalserve_id="g1", nba_date=yesterday, home_team_id="LAL", away_team_id="GSW", home_team_name="Los Angeles Lakers", away_team_name="Golden State Warriors", status="final", home_score=110, away_score=105),
        NBAGame(goalserve_id="g2", nba_date=yesterday, home_team_id="BOS", away_team_id="MIL", home_team_name="Boston Celtics", away_team_name="Milwaukee Bucks", status="final", home_score=115, away_score=120),
        NBAGame(goalserve_id="g3", nba_date=yesterday, home_team_id="DEN", away_team_id="PHX", home_team_name="Denver Nuggets", away_team_name="Phoenix Suns", status="final", home_score=98, away_score=102),
        NBAGame(goalserve_id="g4", nba_date=today, home_team_id="LAL", away_team_id="BOS", home_team_name="Los Angeles Lakers", away_team_name="Boston Celtics", status="live", home_score=85, away_score=80),
        NBAGame(goalserve_id="g5", nba_date=today, home_team_id="GSW", away_team_id="MIL", home_team_name="Golden State Warriors", away_team_name="Milwaukee Bucks", status="scheduled"),
        NBAGame(goalserve_id="g6", nba_date=today, home_team_id="DEN", away_team_id="DAL", home_team_name="Denver Nuggets", away_team_name="Dallas Mavericks", status="scheduled"),
        NBAGame(goalserve_id="g7", nba_date=tomorrow, home_team_id="LAL", away_team_id="DEN", home_team_name="Los Angeles Lakers", away_team_name="Denver Nuggets", status="scheduled"),
        NBAGame(goalserve_id="g8", nba_date=tomorrow, home_team_id="GSW", away_team_id="DAL", home_team_name="Golden State Warriors", away_team_name="Dallas Mavericks", status="scheduled"),
    ]
    await NBAGame.insert_many(nba_games)

    # Seed Player Game Stats for yesterday & today
    print("Seeding Player Game Stats...")
    stats_list = []
    for p in players:
        # Yesterday stats
        stats_y = PlayerGameStats(
            player_id=p.id,
            goalserve_player_id=p.goalserve_id,
            goalserve_game_id="g1" if p.team_name in ("Los Angeles Lakers", "Golden State Warriors") else "g2",
            nba_date=yesterday,
            points=random.randint(10, 35),
            rebounds=random.randint(2, 15),
            assists=random.randint(1, 12),
            steals=random.randint(0, 4),
            blocks=random.randint(0, 3),
            turnovers=random.randint(0, 5),
            field_goals_made=random.randint(5, 12),
            field_goals_attempted=random.randint(10, 22),
            threepoint_made=random.randint(0, 6),
            threepoint_attempted=random.randint(2, 10),
            freethrow_made=random.randint(1, 8),
            freethrow_attempted=random.randint(2, 10),
            minutes_played=random.randint(20, 40),
            did_not_play=False
        )
        stats_y.fantasy_score = compute_fantasy_score(stats_y)
        stats_y.score_computed = True
        stats_list.append(stats_y)

        # Today stats
        stats_t = PlayerGameStats(
            player_id=p.id,
            goalserve_player_id=p.goalserve_id,
            goalserve_game_id="g4" if p.team_name in ("Los Angeles Lakers", "Boston Celtics") else "g5",
            nba_date=today,
            points=random.randint(5, 25),
            rebounds=random.randint(1, 10),
            assists=random.randint(1, 8),
            steals=random.randint(0, 2),
            blocks=random.randint(0, 2),
            turnovers=random.randint(0, 4),
            field_goals_made=random.randint(2, 10),
            field_goals_attempted=random.randint(5, 18),
            threepoint_made=random.randint(0, 4),
            threepoint_attempted=random.randint(1, 8),
            freethrow_made=random.randint(0, 5),
            freethrow_attempted=random.randint(0, 6),
            minutes_played=random.randint(10, 30),
            did_not_play=False
        )
        stats_t.fantasy_score = compute_fantasy_score(stats_t)
        stats_t.score_computed = False
        stats_list.append(stats_t)

    await PlayerGameStats.insert_many(stats_list)

    # Seeding Leagues
    print("Seeding Leagues, Standings, and Lineups...")
    
    leagues_data = [
        {"name": "Global Championship 2026", "type": "global", "status": "regular_season", "max_size": 10, "current_size": 10, "current_match_day": 3, "total_match_days": 18, "admin": None},
        {"name": "Arik's Private Room", "type": "private", "status": "waiting", "max_size": 8, "current_size": 4, "current_match_day": 0, "total_match_days": 14, "admin": users[0]},
        {"name": "Fast Dunkers Arena", "type": "public", "status": "waiting", "max_size": 6, "current_size": 3, "current_match_day": 0, "total_match_days": 10, "admin": users[4]},
        {"name": "Ready to Start Private", "type": "private", "status": "waiting", "max_size": 4, "current_size": 4, "current_match_day": 0, "total_match_days": 6, "admin": users[0]},
        {"name": "Completed Spring Cup", "type": "private", "status": "completed", "max_size": 4, "current_size": 4, "current_match_day": 6, "total_match_days": 6, "admin": users[1]},
        {"name": "Championship Regular", "type": "public", "status": "regular_season", "max_size": 4, "current_size": 4, "current_match_day": 2, "total_match_days": 6, "admin": users[2]},
        {"name": "Active Private League", "type": "private", "status": "regular_season", "max_size": 6, "current_size": 6, "current_match_day": 1, "total_match_days": 10, "admin": users[0]},
        {"name": "Global Cup Season 2", "type": "global", "status": "waiting", "max_size": 10, "current_size": 8, "current_match_day": 0, "total_match_days": 18, "admin": None},
        {"name": "Solo Practice League", "type": "private", "status": "waiting", "max_size": 4, "current_size": 1, "current_match_day": 0, "total_match_days": 6, "admin": users[0]},
        {"name": "Almost Full Public", "type": "public", "status": "waiting", "max_size": 4, "current_size": 3, "current_match_day": 0, "total_match_days": 6, "admin": users[5]},
    ]

    all_memberships = []
    all_quotas = []
    all_matches = []
    all_lineup_slots = []
    all_lineup_submissions = []
    all_flutter_selections = []

    for idx, ldata in enumerate(leagues_data):
        auto_id = idx + 1
        invite_code = League.generate_invite_code() if ldata["type"] == "private" else None
        
        if ldata["name"] == "Arik's Private Room":
            invite_code = "ARIK5M"
        elif ldata["name"] == "Ready to Start Private":
            invite_code = "READY5"
        elif ldata["name"] == "Completed Spring Cup":
            invite_code = "SPRING"

        league = League(
            name=ldata["name"],
            type=ldata["type"],
            status=ldata["status"],
            budget=100,
            max_size=ldata["max_size"],
            current_size=ldata["current_size"],
            invite_code=invite_code,
            admin_id=ldata["admin"].id if ldata["admin"] else None,
            current_match_day=ldata["current_match_day"],
            current_week=(ldata["current_match_day"] - 1) // 2 + 1 if ldata["current_match_day"] > 0 else 0,
            total_match_days=ldata["total_match_days"],
            started_at=datetime.now(timezone.utc) - timedelta(days=5) if ldata["status"] != "waiting" else None,
            ended_at=datetime.now(timezone.utc) if ldata["status"] == "completed" else None,
            auto_id=auto_id,
            description=f"Seeded mock league for testing: {ldata['name']}.",
            logo="lightning"
        )
        await league.insert()

        league_users = users[:ldata["current_size"]]
        user_ids = [u.id for u in league_users]

        for u_idx, u in enumerate(league_users):
            wins = 0
            losses = 0
            points_for = 0.0
            points_against = 0.0

            if ldata["status"] in ("regular_season", "completed"):
                wins = random.randint(0, ldata["current_match_day"])
                losses = ldata["current_match_day"] - wins
                points_for = wins * 150.0 + random.randint(50, 100)
                points_against = losses * 150.0 + random.randint(50, 100)

            all_memberships.append(LeagueMembership(
                league_id=league.id,
                user_id=u.id,
                wins=wins,
                losses=losses,
                points_for=points_for,
                points_against=points_against,
                rank=u_idx + 1
            ))

            all_quotas.append(UserBonusQuota(
                user_id=u.id,
                league_id=league.id,
                luxury_tax_used=random.choice([True, False]),
                chef_curry_used=random.choice([True, False]),
                sixth_man_used=random.choice([True, False])
            ))

        if ldata["status"] in ("regular_season", "completed"):
            schedule = _round_robin_schedule(user_ids)
            match_auto_id_start = (auto_id - 1) * 100

            for md_index, pairings in enumerate(schedule):
                match_day = md_index + 1
                match_date = yesterday - timedelta(days=ldata["current_match_day"] - match_day)
                
                if match_day < ldata["current_match_day"]:
                    m_status = "completed"
                elif match_day == ldata["current_match_day"] and ldata["status"] == "regular_season":
                    m_status = "live"
                else:
                    m_status = "upcoming"

                for pair_idx, (home_id, away_id) in enumerate(pairings):
                    m_auto_id = match_auto_id_start + md_index * 5 + pair_idx
                    
                    home_score = None
                    away_score = None
                    winner_id = None
                    
                    if m_status == "completed":
                        home_score = float(random.randint(120, 195))
                        away_score = float(random.randint(120, 195))
                        winner_id = home_id if home_score >= away_score else away_id
                    elif m_status == "live":
                        home_score = float(random.randint(50, 95))
                        away_score = float(random.randint(50, 95))

                    all_matches.append(LeagueMatch(
                        league_id=league.id,
                        match_day=match_day,
                        nba_date=match_date,
                        home_user_id=home_id,
                        away_user_id=away_id,
                        home_score=home_score,
                        away_score=away_score,
                        winner_id=winner_id,
                        status=m_status,
                        auto_id=m_auto_id
                    ))

                    if match_day <= ldata["current_match_day"]:
                        for player_role_id in (home_id, away_id):
                            # Starters matching positions
                            selected_pg = [p for p in players if p.position == "PG"][0]
                            selected_sg = [p for p in players if p.position == "SG"][0]
                            selected_sf = [p for p in players if p.position == "SF"][0]
                            selected_pf = [p for p in players if p.position == "PF"][0]
                            selected_c = [p for p in players if p.position == "C"][0]

                            five_players = [selected_pg, selected_sg, selected_sf, selected_pf, selected_c]
                            slots = ["PG", "SG", "SF", "PF", "C"]

                            total_score = 0.0
                            for slot_name, p_obj in zip(slots, five_players):
                                f_score = random.randint(25, 45)
                                total_score += f_score
                                
                                all_lineup_slots.append(LineupSlot(
                                    user_id=player_role_id,
                                    league_id=league.id,
                                    nba_date=match_date,
                                    slot=slot_name,
                                    player_id=p_obj.id,
                                    player_goalserve_id=p_obj.goalserve_id,
                                    player_name=p_obj.full_name,
                                    player_position=p_obj.position,
                                    player_price=p_obj.daily_price,
                                    fantasy_score=float(f_score),
                                    score_finalized=(m_status == "completed")
                                ))

                            all_lineup_submissions.append(LineupSubmission(
                                user_id=player_role_id,
                                league_id=league.id,
                                nba_date=match_date,
                                submitted_at=datetime.now(timezone.utc) - timedelta(days=ldata["current_match_day"] - match_day),
                                is_locked=True,
                                locked_at=datetime.now(timezone.utc) - timedelta(days=ldata["current_match_day"] - match_day),
                                total_score=total_score,
                                score_finalized=(m_status == "completed")
                            ))

                            selected_players_list = []
                            for p_obj in five_players:
                                selected_players_list.append({
                                    "id": str(p_obj.id),
                                    "name": p_obj.full_name,
                                    "position": p_obj.position,
                                    "price": f"{p_obj.daily_price}M"
                                })

                            all_flutter_selections.append(FlutterPlayerSelection(
                                user_id=player_role_id,
                                league_id=league.id,
                                league_auto_id=auto_id,
                                match_day=match_day,
                                selected_players=selected_players_list,
                                submitted_at=datetime.now(timezone.utc) - timedelta(days=ldata["current_match_day"] - match_day)
                            ))

    print("Writing memberships, matches, quotas, slots and lineups in bulk...")
    if all_memberships:
        await LeagueMembership.insert_many(all_memberships)
    if all_quotas:
        await UserBonusQuota.insert_many(all_quotas)
    if all_matches:
        await LeagueMatch.insert_many(all_matches)
    if all_lineup_slots:
        await LineupSlot.insert_many(all_lineup_slots)
    if all_lineup_submissions:
        await LineupSubmission.insert_many(all_lineup_submissions)
    if all_flutter_selections:
        await FlutterPlayerSelection.insert_many(all_flutter_selections)

    # Sync leagues auto-increment counter
    await db.counters.update_one({"_id": "leagues"}, {"$set": {"seq": 10}}, upsert=True)
    
    # Sync matches auto-increment counter (10 leagues * 100 matches max)
    await db.counters.update_one({"_id": "league_matches"}, {"$set": {"seq": 1000}}, upsert=True)
    
    print("Seeded all leagues successfully.")

    print("\n--- DATABASE SEED COMPLETED ---")
    print(f"Users: {await User.count()}")
    print(f"Leagues: {await League.count()}")
    print(f"Memberships: {await LeagueMembership.count()}")
    print(f"Matches: {await LeagueMatch.count()}")
    print(f"Players: {await Player.count()}")
    print(f"PlayerGameStats: {await PlayerGameStats.count()}")
    print(f"Games: {await NBAGame.count()}")
    print(f"Wallets: {await TokenWallet.count()}")
    print(f"Transactions: {await TokenTransaction.count()}")
    print(f"LineupSlots: {await LineupSlot.count()}")
    print(f"LineupSubmissions: {await LineupSubmission.count()}")
    print(f"FlutterPlayerSelections: {await FlutterPlayerSelection.count()}")
    print("--------------------------------")

if __name__ == "__main__":
    asyncio.run(main())

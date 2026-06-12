"""
League Rules endpoint — Flutter Rules tab.
Mounted at /api/leagues/rules/

Returns structured game rules content derived from the official Mon5majeur PDFs.
No auth required (rules are public info).
"""
from fastapi import APIRouter

router = APIRouter(tags=["League Rules"])

# ---------------------------------------------------------------------------
# Static rules content — sourced from Mon5majeur PDFs in /rules/
# ---------------------------------------------------------------------------

_RULES: dict = {
    "sections": [
        {
            "id": "objective",
            "title": "Objective",
            "rules": [
                "Build a team of 5 NBA players within your budget.",
                "Your team earns Fantasy Points (FP) based on real NBA game stats.",
                "Compete head-to-head against other managers in your league.",
                "The manager with the most FP wins each match day.",
            ],
        },
        {
            "id": "lineup",
            "title": "Building Your Team",
            "rules": [
                "Select exactly 5 players: 1 Center (C), 2 Wings (SF/PF), 2 Guards (PG/SG).",
                "All 5 players must have a game scheduled tonight.",
                "You cannot select a player marked as OUT (injured).",
                "Total cost of your 5 players must not exceed your budget.",
                "Your team locks at the first tip-off of the evening — no changes after lock.",
            ],
        },
        {
            "id": "budget",
            "title": "Budget",
            "rules": [
                "Standard budget: 80M or 100M (set by league creator).",
                "Player prices are updated every day at 09:00 (Paris time).",
                "Prices are based on each player's last 5 game performances.",
                "Once your lineup is locked, the prices used are frozen for that night.",
            ],
        },
        {
            "id": "scoring",
            "title": "Fantasy Score Formula",
            "rules": [
                "Fantasy Score = (Base + Efficiency) × 0.7  (rounded at the end).",
                "Base = Points + Rebounds + Assists + Steals + Blocks − Turnovers.",
                "3-pointer made: +2 pts  |  3-pointer missed: −2 pts.",
                "2-pointer made: +1 pt   |  2-pointer missed: −1 pt.",
                "Free throw made: +0.5 pt  |  Free throw missed: −0.5 pt.",
                "A player who does not play (DNP) scores 0 FP.",
            ],
        },
        {
            "id": "scoring_example",
            "title": "Scoring Example",
            "rules": [
                "Example — SGA: 31 pts, 2 reb, 8 ast, 0 stl, 1 blk, 3 to.",
                "2/4 from three (2 made, 2 missed) → +4 − 4 = 0.",
                "8/13 from two (8 made, 5 missed) → +8 − 5 = +3.",
                "9/11 free throws (9 made, 2 missed) → +4.5 − 1 = +3.5.",
                "Base = 31+2+8+0+1−3 = 39. Efficiency = 0+3+3.5 = +6.5.",
                "Fantasy Score = (39 + 6.5) × 0.7 = 45.5 × 0.7 = 32 FP.",
            ],
        },
        {
            "id": "duels",
            "title": "Match Day Duels",
            "rules": [
                "Each match day you face one opponent head-to-head.",
                "The manager whose 5 players earn more total FP wins the match.",
                "In case of a tie, the home player (first listed) wins.",
                "A forfeit (no lineup submitted) counts as 0 FP — opponent wins automatically.",
                "Both forfeiting (0 vs 0) → home player wins.",
            ],
        },
        {
            "id": "standings",
            "title": "Standings & Tiebreakers",
            "rules": [
                "Standings are ranked by number of wins.",
                "Tiebreaker 1: Point differential (FP scored − FP conceded).",
                "Tiebreaker 2: Total Fantasy Points scored across all match days.",
                "Tiebreaker 3: Head-to-head result between tied teams.",
                "Tiebreaker 4: Alphabetical order by team name.",
            ],
        },
        {
            "id": "playoffs",
            "title": "Playoffs",
            "rules": [
                "Top 4 teams at the end of the regular season qualify for the playoffs.",
                "Semifinals: 1st vs 4th  and  2nd vs 3rd.",
                "Final: The two semi-final winners face each other.",
                "Playoff seeding bonus: qualifying gives a small budget boost for the next match day.",
            ],
        },
        {
            "id": "bonuses",
            "title": "Strategic Bonuses",
            "rules": [
                "Each user receives a free bonus quota per league (based on league size).",
                "Luxury Tax (+5M budget): use before lineup lock to expand your budget for one night.",
                "Chef Curry (+3 FP): adds 3 bonus points to your total duel score after scoring.",
                "6th Man: add a 6th player (max 8M, any position) — your top 5 scores count.",
                "Extra bonuses can be purchased with tokens from the token shop.",
            ],
        },
        {
            "id": "bonus_quota",
            "title": "Free Bonus Quota per League",
            "rules": [
                "4-team league: 1 Chef Curry, 1 Luxury Tax, 1 Six Man.",
                "6-team league: 2 Chef Curry, 1 Luxury Tax, 2 Six Man.",
                "8-team league: 2 Chef Curry, 2 Luxury Tax, 2 Six Man.",
                "10-team league: 3 Chef Curry, 3 Luxury Tax, 3 Six Man.",
            ],
        },
        {
            "id": "ad_bonus",
            "title": "Video Ad Budget Bonus",
            "rules": [
                "Watch a short video ad to earn a temporary budget bonus — free for all users.",
                "Private league: +2M budget (15-second ad, once per day per league).",
                "Public / Global league: +10M budget (20-second ad, twice per week).",
                "This bonus is NOT a paid advantage — every manager has equal access.",
            ],
        },
        {
            "id": "league_types",
            "title": "League Types",
            "rules": [
                "Private League: invite-code only, 4–10 players, head-to-head duels, bonuses available.",
                "Public League: open/listed, same duel rules as private, join any time.",
                "Global League: world ranking, everyone competes, 100M fixed budget, no bonuses.",
                "Private & Public leagues auto-delete if the creator does not start within 7 days.",
            ],
        },
        {
            "id": "schedule",
            "title": "Daily Schedule",
            "rules": [
                "09:00 Paris: Final scores computed, standings updated, prices recomputed.",
                "19:00 Paris: Reminder notification if you have no lineup yet.",
                "First tip-off: Lineups lock — no more changes for the night.",
                "Match days follow the US/Eastern NBA calendar (not Paris date).",
            ],
        },
    ]
}


@router.get(
    "/leagues/rules/",
    summary="League rules content (Flutter: Rules tab)",
)
async def get_league_rules() -> dict:
    return _RULES

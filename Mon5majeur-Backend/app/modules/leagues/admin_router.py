"""
Admin (dashboard) League Management: catalog counters + the Global League
"Top Players" leaderboard for a given month.
Mounted at /api to match the dashboard's hardcoded base URL.
"""
from __future__ import annotations

from calendar import monthrange
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from app.modules.auth.dependencies import get_current_superuser
from app.modules.leagues.constants import LEAGUE_TYPE_GLOBAL, LEAGUE_TYPE_PRIVATE, LEAGUE_TYPE_PUBLIC
from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
from app.modules.leagues.model import League, LeagueMembership
from app.modules.leagues.reward_model import GlobalLeagueReward
from app.modules.users.model import User

router = APIRouter(
    prefix="/admin/leagues",
    tags=["Admin: League Management"],
    dependencies=[Depends(get_current_superuser)],
)


class LeagueStatsResponse(BaseModel):
    total_global_leagues: int
    total_public_leagues: int
    total_private_leagues: int
    private_league_players: int   # distinct users with a membership in a private league
    global_league_players: int    # distinct users who have joined the Global League


class LeaderboardRow(BaseModel):
    rank: int
    user_id: str
    team_name: str
    score: float
    monthly_winner: bool  # this user holds the GlobalLeagueReward "rank 1" for this month


class GlobalLeaderboardResponse(BaseModel):
    year: int
    month: int
    rows: list[LeaderboardRow]


@router.get("/stats/", response_model=LeagueStatsResponse, summary="League catalog counters")
async def league_stats() -> LeagueStatsResponse:
    total_global = await League.find(League.type == LEAGUE_TYPE_GLOBAL).count()
    total_public = await League.find(League.type == LEAGUE_TYPE_PUBLIC).count()
    total_private = await League.find(League.type == LEAGUE_TYPE_PRIVATE).count()

    private_ids = [lg.id for lg in await League.find(League.type == LEAGUE_TYPE_PRIVATE).to_list()]
    global_ids = [lg.id for lg in await League.find(League.type == LEAGUE_TYPE_GLOBAL).to_list()]

    private_players = await _distinct_member_count(private_ids)
    global_players = await _distinct_member_count(global_ids)

    return LeagueStatsResponse(
        total_global_leagues=total_global,
        total_public_leagues=total_public,
        total_private_leagues=total_private,
        private_league_players=private_players,
        global_league_players=global_players,
    )


async def _distinct_member_count(league_ids: list) -> int:
    if not league_ids:
        return 0
    rows = await LeagueMembership.aggregate(
        [
            {"$match": {"league_id": {"$in": league_ids}}},
            {"$group": {"_id": "$user_id"}},
            {"$count": "n"},
        ]
    ).to_list()
    return rows[0]["n"] if rows else 0


@router.get(
    "/global-leaderboard/",
    response_model=GlobalLeaderboardResponse,
    summary="Global League Top Players for a given month",
)
async def global_leaderboard(
    year: int = Query(..., ge=2020, le=2100),
    month: int = Query(..., ge=1, le=12),
) -> GlobalLeaderboardResponse:
    global_ids = [lg.id for lg in await League.find(League.type == LEAGUE_TYPE_GLOBAL).to_list()]
    if not global_ids:
        return GlobalLeaderboardResponse(year=year, month=month, rows=[])

    # Beanie stores a `date` field as a naive midnight BSON datetime (see
    # analytics.service) — the match range must be naive too, or it silently
    # matches nothing.
    days_in_month = monthrange(year, month)[1]
    range_start = datetime(year, month, 1)
    range_end = datetime(year, month, days_in_month)

    rows = await GlobalLeagueDailyScore.aggregate(
        [
            {
                "$match": {
                    "league_id": {"$in": global_ids},
                    "nba_date": {"$gte": range_start, "$lte": range_end},
                }
            },
            {"$group": {"_id": "$user_id", "total": {"$sum": "$total_points"}}},
            {"$sort": {"total": -1}},
        ]
    ).to_list()

    if not rows:
        return GlobalLeaderboardResponse(year=year, month=month, rows=[])

    user_ids = [r["_id"] for r in rows]
    users = {u.id: u for u in await User.find({"_id": {"$in": user_ids}}).to_list()}

    period_key = f"{year:04d}-{month:02d}"
    monthly_winners = {
        r.user_id
        for r in await GlobalLeagueReward.find(
            GlobalLeagueReward.period_type == "monthly",
            GlobalLeagueReward.period_key == period_key,
            GlobalLeagueReward.rank == 1,
        ).to_list()
    }

    leaderboard_rows = [
        LeaderboardRow(
            rank=i + 1,
            user_id=str(r["_id"]),
            team_name=(users.get(r["_id"]).team_name or users.get(r["_id"]).email)
            if users.get(r["_id"])
            else "Unknown",
            score=round(r["total"], 2),
            monthly_winner=r["_id"] in monthly_winners,
        )
        for i, r in enumerate(rows)
    ]

    return GlobalLeaderboardResponse(year=year, month=month, rows=leaderboard_rows)

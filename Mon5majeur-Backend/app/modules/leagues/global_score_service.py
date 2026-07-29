"""
NBA Global League daily-score archive + Weekly/Monthly ranking.

The Global League stores only the user's *current* player selection
(FlutterPlayerSelection) — there's no per-night history. To rank players by
week/month we archive each night's computed score into GlobalLeagueDailyScore
once that night's games are final (called from the 09:00 Paris daily-close
cron job, after PlayerGameStats has been finalized for the night).
"""
from __future__ import annotations

from datetime import date, timedelta

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
from app.modules.leagues.model import League, LeagueMembership
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.model import PlayerGameStats

logger = get_logger(__name__)


async def _score_selection(selected_players: list[dict], nba_date: date) -> float:
    total = 0.0
    for p in selected_players:
        raw_id = p.get("id")
        if not raw_id:
            continue
        try:
            player_id = PydanticObjectId(str(raw_id))
        except Exception:
            continue
        stat = await PlayerGameStats.find_one(
            PlayerGameStats.player_id == player_id,
            PlayerGameStats.nba_date == nba_date,
        )
        if stat and stat.fantasy_score:
            total += stat.fantasy_score
    return round(total, 2)


async def archive_daily_scores(nba_date: date) -> int:
    """Snapshot every Global League member's score for `nba_date`.
    Idempotent — safe to re-run for the same date (upserts by unique index)."""
    league = await League.find_one(League.type == "global")
    if not league:
        return 0

    selections = await FlutterPlayerSelection.find(
        FlutterPlayerSelection.league_auto_id == league.auto_id
    ).to_list()

    count = 0
    for sel in selections:
        score = await _score_selection(sel.selected_players, nba_date)

        existing = await GlobalLeagueDailyScore.find_one(
            GlobalLeagueDailyScore.user_id == sel.user_id,
            GlobalLeagueDailyScore.league_id == league.id,
            GlobalLeagueDailyScore.nba_date == nba_date,
        )
        if existing:
            existing.total_points = score
            await existing.save()
        else:
            await GlobalLeagueDailyScore(
                user_id=sel.user_id,
                league_id=league.id,
                nba_date=nba_date,
                total_points=score,
            ).insert()
        count += 1

    logger.info("Archived %d Global League daily scores for %s", count, nba_date)
    return count


def _week_bounds(today: date) -> tuple[date, date]:
    start = today - timedelta(days=today.weekday())  # Monday
    return start, start + timedelta(days=6)


def _month_bounds(today: date) -> tuple[date, date]:
    start = today.replace(day=1)
    next_month = start.replace(year=start.year + 1, month=1) if start.month == 12 \
        else start.replace(month=start.month + 1)
    return start, next_month - timedelta(days=1)


async def _ranked_totals_for_period(
    league: League, start: date, end: date
) -> list[tuple[PydanticObjectId, float]]:
    """All Global League members ranked by summed score over [start, end],
    descending. Members with no archived score that period score 0."""
    memberships = await LeagueMembership.find(
        LeagueMembership.league_id == league.id
    ).to_list()
    member_ids = {m.user_id for m in memberships}

    scores = await GlobalLeagueDailyScore.find(
        GlobalLeagueDailyScore.league_id == league.id,
        GlobalLeagueDailyScore.nba_date >= start,
        GlobalLeagueDailyScore.nba_date <= end,
    ).to_list()

    totals: dict[PydanticObjectId, float] = {uid: 0.0 for uid in member_ids}
    for s in scores:
        if s.user_id in totals:
            totals[s.user_id] += s.total_points

    return sorted(totals.items(), key=lambda kv: kv[1], reverse=True)


async def _rank_for_period(
    league: League, user_id: PydanticObjectId, start: date, end: date
) -> int | None:
    memberships = await LeagueMembership.find(
        LeagueMembership.league_id == league.id
    ).to_list()
    if not any(m.user_id == user_id for m in memberships):
        return None

    ranked = await _ranked_totals_for_period(league, start, end)
    for idx, (uid, _) in enumerate(ranked, start=1):
        if uid == user_id:
            return idx
    return None


async def get_weekly_monthly_rank(
    league: League, user_id: PydanticObjectId, today: date
) -> tuple[int | None, int | None]:
    week_start, week_end = _week_bounds(today)
    month_start, month_end = _month_bounds(today)

    weekly_rank = await _rank_for_period(league, user_id, week_start, week_end)
    monthly_rank = await _rank_for_period(league, user_id, month_start, month_end)
    return weekly_rank, monthly_rank


# ---------------------------------------------------------------------------
# Rewards (spec §4.6.1): Top 8 weekly -> in-game bonus, monthly #1 -> jersey.
# Called by the Monday/1st-of-month 09:00 Paris cron jobs, right after that
# period's reset. Idempotent via GlobalLeagueReward's unique index.
# ---------------------------------------------------------------------------

_WEEKLY_TOP_N = 8
_WEEKLY_REWARD_BONUS = "sixth_man"   # product choice: which bonus Top-8 grants


async def grant_weekly_top8_reward(week_end: date) -> int:
    """Grant the just-finished week's Top 8 one free bonus charge each.
    `week_end` = the Sunday that just closed (call the Monday morning after)."""
    from app.modules.bonuses.model import UserBonusInventory
    from app.modules.leagues.reward_model import GlobalLeagueReward
    from app.modules.notifications.service import NotificationService

    league = await League.find_one(League.type == "global")
    if not league:
        return 0

    week_start = week_end - timedelta(days=6)
    ranked = await _ranked_totals_for_period(league, week_start, week_end)
    period_key = f"{week_start.isocalendar().year}-W{week_start.isocalendar().week:02d}"

    notif = NotificationService()
    granted = 0
    for rank, (user_id, _score) in enumerate(ranked[:_WEEKLY_TOP_N], start=1):
        existing = await GlobalLeagueReward.find_one(
            GlobalLeagueReward.user_id == user_id,
            GlobalLeagueReward.period_type == "weekly",
            GlobalLeagueReward.period_key == period_key,
        )
        if existing:
            continue

        inv = await UserBonusInventory.find_one(UserBonusInventory.user_id == user_id)
        if not inv:
            inv = UserBonusInventory(user_id=user_id)
            await inv.insert()
        field = f"{_WEEKLY_REWARD_BONUS}_charges"
        setattr(inv, field, getattr(inv, field) + 1)
        await inv.save()

        await GlobalLeagueReward(
            user_id=user_id, period_type="weekly", period_key=period_key,
            rank=rank, granted_at=week_end,
        ).insert()

        await notif.send_push_to_user(
            user_id=user_id,
            title="🏆 Top 8 this week!",
            body="You finished in the Global League's weekly Top 8 — a bonus was added to your inventory.",
            data={"type": "weekly_top8_reward"},
        )
        granted += 1

    logger.info("Granted weekly Top-%d reward to %d users for %s", _WEEKLY_TOP_N, granted, period_key)
    return granted


async def grant_monthly_winner_reward(month_end: date) -> int:
    """Record the just-finished month's #1 (spec: NBA jersey reward).
    Physical fulfillment (shipping the jersey) is manual — this only
    identifies the winner, records it, and notifies them."""
    from app.modules.leagues.reward_model import GlobalLeagueReward
    from app.modules.notifications.service import NotificationService

    league = await League.find_one(League.type == "global")
    if not league:
        return 0

    month_start = month_end.replace(day=1)
    ranked = await _ranked_totals_for_period(league, month_start, month_end)
    if not ranked:
        return 0

    period_key = f"{month_start.year}-{month_start.month:02d}"
    winner_id, _score = ranked[0]

    existing = await GlobalLeagueReward.find_one(
        GlobalLeagueReward.user_id == winner_id,
        GlobalLeagueReward.period_type == "monthly",
        GlobalLeagueReward.period_key == period_key,
    )
    if existing:
        return 0

    await GlobalLeagueReward(
        user_id=winner_id, period_type="monthly", period_key=period_key,
        rank=1, granted_at=month_end,
    ).insert()

    notif = NotificationService()
    await notif.send_push_to_user(
        user_id=winner_id,
        title="🏆 You won the month!",
        body="You're #1 in the Global League this month — an NBA jersey is on its way. We'll be in touch.",
        data={"type": "monthly_winner_reward"},
    )

    logger.info("Recorded monthly winner %s for %s", winner_id, period_key)
    return 1

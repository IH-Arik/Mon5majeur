"""
CRON job definitions.

Schedule (all times are Europe/Paris):
  12:00  sync_today_schedule_job — fetch tonight's NBA games from Goalserve → NBAGame docs
  01:00–09:00 every 20 min — sync_live_games_job — pull box-scores for live/finished games
  09:00  daily_close_job  — score finalize → standings → price recompute
  09:05  weekly_monthly_rewards_job — Mon: Top-8 weekly bonus; 1st: monthly jersey winner
  19:00  reminder_job     — push "don't forget your team" to users who haven't submitted
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# 09:00 Paris — daily close (strict order: scores → standings → prices)
# ---------------------------------------------------------------------------

async def daily_close_job() -> None:
    from app.modules.leagues.engine import run_daily_close
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    today = datetime.now(timezone.utc).date()
    logger.info("CRON daily_close_job: starting for %s", today)

    try:
        # 1. Finalize all slot scores from PlayerGameStats
        from app.modules.lineups.service import LineupService
        from app.modules.bonuses.service import BonusService
        lineup_svc = LineupService(BonusService())

        filled = await lineup_svc.fill_slot_scores_from_stats(today)
        logger.info("CRON: filled %d slot scores", filled)

        finalized = await lineup_svc.finalize_lineup_scores(today)
        logger.info("CRON: finalized %d lineup total scores", finalized)

        # 2. Score matches + update standings + advance match days
        result = await run_daily_close(today)
        logger.info("CRON: league engine done: %s", result)

        # 3. Recompute player prices
        player_svc = PlayerService(PlayerRepository())
        price_count = await player_svc.recompute_all_prices()
        logger.info("CRON: recomputed %d player prices", price_count)

        # 4. Archive last night's Global League scores (feeds Weekly/Monthly rank)
        from app.modules.leagues.global_score_service import archive_daily_scores
        archived = await archive_daily_scores(today)
        logger.info("CRON: archived %d Global League daily scores", archived)

    except Exception as exc:
        logger.error("CRON daily_close_job failed: %s", exc, exc_info=True)


# ---------------------------------------------------------------------------
# 09:05 Paris — weekly/monthly Global League rewards (spec §4.6.1 / §5.2)
# Runs daily but only acts on the days the reset actually happens, right
# after daily_close_job has archived that night's scores.
# ---------------------------------------------------------------------------

async def weekly_monthly_rewards_job() -> None:
    from app.modules.leagues.global_score_service import (
        grant_monthly_winner_reward,
        grant_weekly_top8_reward,
    )

    today = datetime.now(timezone.utc).date()
    yesterday = today - timedelta(days=1)
    logger.info("CRON weekly_monthly_rewards_job: checking resets for %s", today)

    try:
        if today.weekday() == 0:  # Monday → the week ending yesterday (Sunday) just closed
            granted = await grant_weekly_top8_reward(yesterday)
            logger.info("CRON: granted weekly Top-8 reward to %d users", granted)

        if today.day == 1:  # 1st of month → the month ending yesterday just closed
            granted = await grant_monthly_winner_reward(yesterday)
            logger.info("CRON: recorded monthly winner (%d)", granted)

    except Exception as exc:
        logger.error("CRON weekly_monthly_rewards_job failed: %s", exc, exc_info=True)


# ---------------------------------------------------------------------------
# 19:00 Paris — reminder push
# ---------------------------------------------------------------------------

async def reminder_push_job() -> None:
    logger.info("CRON reminder_push_job: starting")
    try:
        await _send_reminder_pushes()
    except Exception as exc:
        logger.error("CRON reminder_push_job failed: %s", exc, exc_info=True)


async def _send_reminder_pushes() -> None:
    from app.modules.leagues.model import League, LeagueMembership
    from app.modules.lineups.compat_model import FlutterPlayerSelection

    # NOTE: the team builder actually saves to FlutterPlayerSelection (the
    # Django-compat store keyed by league_auto_id + match_day), not
    # LineupSubmission — checking LineupSubmission here meant this reminder
    # fired for every user every night regardless of whether they'd already
    # set their team. See engine.py::score_match_day for the same root cause.
    active_leagues = await League.find(
        {"status": {"$in": ["regular_season", "playoffs"]}}  # "waiting" = no night to remind about yet
    ).to_list()

    notified: set = set()

    for league in active_leagues:
        if league.auto_id is None:
            continue

        memberships = await LeagueMembership.find(
            LeagueMembership.league_id == league.id
        ).to_list()

        for m in memberships:
            if m.user_id in notified:
                continue

            already_submitted = await FlutterPlayerSelection.find_one(
                FlutterPlayerSelection.user_id == m.user_id,
                FlutterPlayerSelection.league_auto_id == league.auto_id,
                FlutterPlayerSelection.match_day == league.current_match_day,
            )

            if not already_submitted:
                await _send_fcm_reminder(m.user_id)
                notified.add(m.user_id)


async def _send_fcm_reminder(user_id) -> None:
    from app.modules.notifications.service import NotificationService
    svc = NotificationService()
    await svc.send_push_to_user(
        user_id=user_id,
        title="Don't forget your team!",
        body="Lock in your lineup before tip-off.",
        data={"type": "team_reminder"},
    )


# ---------------------------------------------------------------------------
# 06:00 Paris — sync NBA player roster (daily, catches trades & signings)
# ---------------------------------------------------------------------------

async def sync_player_roster_job() -> None:
    """
    Pull the full NBA playerIndex from NBA CDN and upsert into Player collection.
    Runs once a day at 06:00 Paris so roster changes (trades, signings, injuries)
    are reflected before the 12:00 schedule sync and evening games.
    """
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    logger.info("CRON sync_player_roster_job: fetching NBA CDN playerIndex")
    try:
        svc = PlayerService(PlayerRepository())
        count = await svc.sync_from_goalserve("nba")
        logger.info("CRON: synced %d players from NBA CDN playerIndex", count)
    except Exception as exc:
        logger.error("CRON sync_player_roster_job failed: %s", exc, exc_info=True)


# ---------------------------------------------------------------------------
# 12:00 Paris — sync today's NBA schedule from Goalserve
# ---------------------------------------------------------------------------

async def sync_today_schedule_job() -> None:
    """
    Fetch tonight's NBA game schedule from NBA CDN scoreboard.
    Passing None uses todaysScoreboard_00.json which always reflects the current NBA date.
    """
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    logger.info("CRON sync_today_schedule_job: fetching today's NBA schedule")
    try:
        svc = PlayerService(PlayerRepository())
        count = await svc.sync_schedule(None)  # None → todaysScoreboard_00.json
        logger.info("CRON: synced %d games from NBA CDN scoreboard", count)
    except Exception as exc:
        logger.error("CRON sync_today_schedule_job failed: %s", exc, exc_info=True)


# ---------------------------------------------------------------------------
# Every 20 min (01:00–09:00 Paris) — pull box-scores for live/finished games
# ---------------------------------------------------------------------------

async def sync_live_games_job() -> None:
    """
    Poll Goalserve for all live or just-finished games today.
    For each finished game: sync box-score → compute fantasy scores.
    This feeds PlayerGameStats so that daily_close_job at 09:00 finds data ready.
    """
    from app.modules.players.model import NBAGame
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    today = datetime.now(timezone.utc).date()
    logger.info("CRON sync_live_games_job: checking live/finished games for %s", today)

    try:
        svc = PlayerService(PlayerRepository())

        # Re-sync schedule to update game statuses (live / final)
        await svc.sync_schedule(today)

        # Fetch all games for today
        games = await NBAGame.find(NBAGame.nba_date == today).to_list()
        if not games:
            logger.info("CRON sync_live_games_job: no games today, skipping")
            return

        # Flip tonight's matches from upcoming -> live (feeds Night's Results
        # LIVE badge + Live Score; only the 09:00 close ever marks "completed")
        from app.modules.leagues.engine import sync_match_live_status
        flipped = await sync_match_live_status(today)
        if flipped:
            logger.info("CRON: marked %d matches live", flipped)

        for game in games:
            if game.status not in ("live", "final"):
                continue

            # Sync box-score stats from Goalserve
            synced = await svc.sync_game_stats(game.goalserve_id)
            logger.info(
                "CRON: synced %d stat rows for game %s (status=%s)",
                synced, game.goalserve_id, game.status,
            )

            # Compute fantasy scores for this game's stats (idempotent)
            if game.status == "final":
                scored = await svc.finalize_game_scores(game.goalserve_id)
                if scored:
                    logger.info(
                        "CRON: computed %d fantasy scores for finished game %s",
                        scored, game.goalserve_id,
                    )

    except Exception as exc:
        logger.error("CRON sync_live_games_job failed: %s", exc, exc_info=True)

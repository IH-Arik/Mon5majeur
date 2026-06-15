"""
CRON job definitions.

Schedule (all times are Europe/Paris):
  12:00  sync_today_schedule_job — fetch tonight's NBA games from Goalserve → NBAGame docs
  01:00–09:00 every 20 min — sync_live_games_job — pull box-scores for live/finished games
  09:00  daily_close_job  — score finalize → standings → price recompute
  19:00  reminder_job     — push "don't forget your team" to users who haven't submitted
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone

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

    except Exception as exc:
        logger.error("CRON daily_close_job failed: %s", exc, exc_info=True)


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
    from app.modules.lineups.model import LineupSubmission

    today = datetime.now(timezone.utc).date()

    # Find all active leagues
    active_leagues = await League.find(
        {"status": {"$in": ["waiting", "regular_season", "playoffs"]}}
    ).to_list()

    notified: set = set()

    for league in active_leagues:
        memberships = await LeagueMembership.find(
            LeagueMembership.league_id == league.id
        ).to_list()

        for m in memberships:
            if m.user_id in notified:
                continue

            already_submitted = await LineupSubmission.find_one(
                LineupSubmission.user_id == m.user_id,
                LineupSubmission.league_id == league.id,
                LineupSubmission.nba_date == today,
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

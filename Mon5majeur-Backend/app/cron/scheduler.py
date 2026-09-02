"""
APScheduler setup. Registered on FastAPI startup / shutdown.

Timezone for all cron triggers: Europe/Paris
"""
from __future__ import annotations

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None

PARIS_TZ = "Europe/Paris"


# Every minute across the NBA window (spec §4.5: the premium live score
# refreshes every 1 minute during games). Early slates can tip off as soon
# as ~19:30 Paris (spec §4.1), so the window opens at 19:00 rather than
# 01:00. sync_live_games_job skips the Goalserve call whenever no game is
# actually in progress, so an idle night costs nothing.
#
# Exposed as a function so the schedule can be asserted on without starting
# the scheduler.
LIVE_POLL_HOURS = "19-23,0-9"
LIVE_POLL_MINUTES = "*"


def live_poll_trigger() -> CronTrigger:
    return CronTrigger(
        hour=LIVE_POLL_HOURS, minute=LIVE_POLL_MINUTES, timezone=PARIS_TZ
    )


def get_scheduler() -> AsyncIOScheduler:
    global _scheduler
    if _scheduler is None:
        _scheduler = AsyncIOScheduler(timezone=PARIS_TZ)
    return _scheduler


def start_scheduler() -> None:
    from app.cron.jobs import (
        cleanup_stale_leagues_job,
        daily_close_job,
        reminder_push_job,
        sync_live_games_job,
        sync_player_roster_job,
        sync_today_schedule_job,
        weekly_monthly_rewards_job,
    )

    scheduler = get_scheduler()

    # 06:00 Paris — sync NBA player roster (trades, signings, injuries)
    scheduler.add_job(
        sync_player_roster_job,
        CronTrigger(hour=6, minute=0, timezone=PARIS_TZ),
        id="sync_player_roster",
        replace_existing=True,
        misfire_grace_time=600,
    )

    # 12:00 Paris — fetch tonight's game schedule from Goalserve
    scheduler.add_job(
        sync_today_schedule_job,
        CronTrigger(hour=12, minute=0, timezone=PARIS_TZ),
        id="sync_schedule",
        replace_existing=True,
        misfire_grace_time=300,
    )

    scheduler.add_job(
        sync_live_games_job,
        live_poll_trigger(),
        id="sync_live_games",
        replace_existing=True,
        misfire_grace_time=60,
        max_instances=1,   # a slow Goalserve reply must not stack up pollers
    )

    # 09:00 Paris — daily close (scores → standings → prices)
    scheduler.add_job(
        daily_close_job,
        CronTrigger(hour=9, minute=0, timezone=PARIS_TZ),
        id="daily_close",
        replace_existing=True,
        misfire_grace_time=300,
    )

    # 09:05 Paris — weekly Top-8 / monthly winner rewards (after daily_close archives scores)
    scheduler.add_job(
        weekly_monthly_rewards_job,
        CronTrigger(hour=9, minute=5, timezone=PARIS_TZ),
        id="weekly_monthly_rewards",
        replace_existing=True,
        misfire_grace_time=300,
    )

    # 09:10 Paris — delete leagues the creator never started within 7 days
    scheduler.add_job(
        cleanup_stale_leagues_job,
        CronTrigger(hour=9, minute=10, timezone=PARIS_TZ),
        id="cleanup_stale_leagues",
        replace_existing=True,
        misfire_grace_time=300,
    )

    # 19:00 Paris — reminder push
    scheduler.add_job(
        reminder_push_job,
        CronTrigger(hour=19, minute=0, timezone=PARIS_TZ),
        id="reminder_push",
        replace_existing=True,
        misfire_grace_time=300,
    )

    scheduler.start()
    logger.info("APScheduler started (timezone=%s)", PARIS_TZ)


def stop_scheduler() -> None:
    scheduler = get_scheduler()
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("APScheduler stopped")

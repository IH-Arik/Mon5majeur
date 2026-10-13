"""
APScheduler setup. Registered on FastAPI startup / shutdown.

Timezone for all cron triggers: Europe/Paris
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

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
# Window after 09:00 Paris in which a late scheduler start still runs the daily
# close (see _schedule_close_catch_up), and the misfire grace of the close jobs
# if the process itself was stalled past their slot.
_CLOSE_GRACE_SECONDS = 3 * 3600

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


def _schedule_close_catch_up(scheduler: AsyncIOScheduler, job) -> None:
    """Run the daily close once if the scheduler (re)started just after its
    09:00 slot (QA #12: a 09:19 restart skipped the close).

    APScheduler never fires a slot that passed before the process started, so
    `misfire_grace_time` cannot cover this: the catch-up is scheduled by hand.
    It is safe when the close already ran today: daily_close_job takes a
    per-day lock (6 h) and returns at once when it is held, and a close that
    already ran finds no duel pending."""
    now = datetime.now(ZoneInfo(PARIS_TZ))
    start = now.replace(hour=9, minute=0, second=0, microsecond=0)
    if not (start <= now < start + timedelta(seconds=_CLOSE_GRACE_SECONDS)):
        return
    scheduler.add_job(
        job,
        "date",
        run_date=now + timedelta(seconds=30),
        id="daily_close_catch_up",
        replace_existing=True,
    )
    logger.info("Restart after 09:00 Paris: daily close catch-up scheduled")


def start_scheduler() -> None:
    from app.cron.jobs import (
        cleanup_stale_leagues_job,
        daily_close_job,
        prepare_night_job,
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

    # 08:30 Paris — fetch and score the night that just ended, so the 09:00
    # close is quick and the results are out at 09:00 sharp
    scheduler.add_job(
        prepare_night_job,
        CronTrigger(hour=8, minute=30, timezone=PARIS_TZ),
        id="prepare_night",
        replace_existing=True,
        misfire_grace_time=_CLOSE_GRACE_SECONDS,
        max_instances=1,
    )

    # 09:00 Paris — daily close (scores → standings → prices)
    scheduler.add_job(
        daily_close_job,
        CronTrigger(hour=9, minute=0, timezone=PARIS_TZ),
        id="daily_close",
        replace_existing=True,
        misfire_grace_time=_CLOSE_GRACE_SECONDS,
    )

    # 09:05 Paris — weekly Top-8 / monthly winner rewards (after daily_close archives scores)
    scheduler.add_job(
        weekly_monthly_rewards_job,
        CronTrigger(hour=9, minute=5, timezone=PARIS_TZ),
        id="weekly_monthly_rewards",
        replace_existing=True,
        misfire_grace_time=_CLOSE_GRACE_SECONDS,
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
    _schedule_close_catch_up(scheduler, daily_close_job)


def stop_scheduler() -> None:
    scheduler = get_scheduler()
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("APScheduler stopped")

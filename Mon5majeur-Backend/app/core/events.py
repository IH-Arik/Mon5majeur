from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI

from app.core.config import settings
from app.core.logging import configure_logging, get_logger
from app.database.session import close_db, init_db

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    configure_logging()
    logger.info("Starting up %s...", app.title)

    try:
        await init_db()
        logger.info("MongoDB connected and Beanie initialised.")
    except Exception as exc:
        logger.critical("Cannot connect to MongoDB: %s", exc)
        raise

    # Start CRON scheduler
    if settings.ENABLE_SCHEDULER:
        from app.cron.scheduler import start_scheduler
        start_scheduler()

    # Seed real NBA data on first boot (if collections are empty)
    await _seed_if_empty()

    yield

    logger.info("Shutting down...")

    if settings.ENABLE_SCHEDULER:
        from app.cron.scheduler import stop_scheduler
        stop_scheduler()

    await close_db()
    logger.info("MongoDB connection closed.")


async def _seed_if_empty() -> None:
    """
    On first boot: if the Player collection is empty, pull the full NBA roster
    from NBA CDN and sync today's game schedule.
    Subsequent boots skip this (players already exist).
    """
    from app.modules.players.model import Player
    from app.modules.players.repository import PlayerRepository
    from app.modules.players.service import PlayerService

    try:
        count = await Player.count()
        if count > 0:
            logger.info("Startup seed: %d players already in DB, skipping.", count)
            return

        logger.info("Startup seed: Player collection empty — syncing NBA roster + today's schedule …")
        svc = PlayerService(PlayerRepository())

        # 1. Full NBA roster (587 players)
        synced = await svc.sync_from_goalserve("nba")
        logger.info("Startup seed: synced %d players from NBA CDN", synced)

        # 2. Today's game schedule
        schedule_count = await svc.sync_schedule(None)
        logger.info("Startup seed: synced %d games from NBA CDN scoreboard", schedule_count)

    except Exception as exc:
        logger.error("Startup seed failed (non-fatal): %s", exc, exc_info=True)

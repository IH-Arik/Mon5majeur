"""
Cross-process job lock (audit 1.1 - double-fire cron).

The scheduler runs inside every API process that has ENABLE_SCHEDULER on, so a
misconfigured deploy (several workers/replicas) fires every job several times.
The real fix is one scheduler container; this lock is the safety net: only the
first process to claim `key` runs the job, the others skip it.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from beanie import Document
from pymongo import ASCENDING, IndexModel
from pymongo.errors import DuplicateKeyError

from app.core.logging import get_logger

logger = get_logger(__name__)


class JobLock(Document):
    key: str
    expires_at: datetime
    holder: str | None = None

    class Settings:
        name = "job_locks"
        indexes = [
            IndexModel([("key", ASCENDING)], unique=True),
            IndexModel([("expires_at", ASCENDING)], expireAfterSeconds=0),
        ]


async def try_acquire(key: str, ttl_seconds: int = 6 * 3600) -> bool:
    """True if this process now owns `key`; False if another one already does.

    Fails OPEN: if the lock itself cannot be used (collection not registered in
    this process, Mongo hiccup) the job still runs - the lock is a safety net
    against double-firing, and must never be the reason a nightly close does
    not happen."""
    import os

    try:
        await JobLock.get_motor_collection().insert_one(
            {
                "key": key,
                "holder": f"pid{os.getpid()}",
                "expires_at": datetime.now(timezone.utc) + timedelta(seconds=ttl_seconds),
            }
        )
        return True
    except DuplicateKeyError:
        logger.warning("Job lock %s already held by another process - skipping", key)
        return False
    except Exception as exc:  # noqa: BLE001
        logger.error("Job lock %s unavailable (%s) - running WITHOUT the lock", key, exc)
        return True


async def release(key: str) -> None:
    """Free the lock so a failed run can be retried."""
    try:
        await JobLock.get_motor_collection().delete_one({"key": key})
    except Exception as exc:  # noqa: BLE001
        logger.error("Could not release job lock %s: %s", key, exc)

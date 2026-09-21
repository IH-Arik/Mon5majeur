"""
Small MongoDB-backed rate limiter for the auth endpoints (audit 2.1).

Counters live in Mongo (not in process memory) so the limit is shared by every
API worker/replica — an in-memory limiter would be multiplied by the number of
workers. Fixed windows; each counter expires on its own (TTL index).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from beanie import Document
from pymongo import ASCENDING, IndexModel, ReturnDocument

from app.core.logging import get_logger
from app.exceptions.errors import RateLimitException

logger = get_logger(__name__)


class RateLimitBucket(Document):
    key: str
    hits: int = 0
    expires_at: datetime

    class Settings:
        name = "rate_limit_buckets"
        indexes = [
            IndexModel([("key", ASCENDING)], unique=True),
            IndexModel([("expires_at", ASCENDING)], expireAfterSeconds=0),
        ]


async def hit(key: str, limit: int, window_seconds: int) -> None:
    """Count one request against `key`; raise RateLimitException (429) once
    more than `limit` requests fall in the current window."""
    now = datetime.now(timezone.utc)
    window = int(now.timestamp() // window_seconds)
    retry_after = window_seconds - int(now.timestamp() % window_seconds)
    doc = await RateLimitBucket.get_motor_collection().find_one_and_update(
        {"key": f"{key}:{window}"},
        {
            "$inc": {"hits": 1},
            "$setOnInsert": {"expires_at": now + timedelta(seconds=window_seconds * 2)},
        },
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    if doc["hits"] > limit:
        logger.warning("Rate limit hit | key=%s | hits=%s | limit=%s", key, doc["hits"], limit)
        raise RateLimitException(
            "Too many attempts. Please try again in a few minutes.",
            headers={"Retry-After": str(max(retry_after, 1))},
        )


def client_ip(request) -> str:
    """The real client IP.

    nginx faces the internet directly and sets X-Real-IP from $remote_addr,
    OVERWRITING any value the client sent - so it is trustworthy. X-Forwarded-For
    is deliberately NOT used: nginx only APPENDS the real IP to whatever the
    client put in it, so its first element is attacker-controlled and would let
    anyone dodge the per-IP limit by sending a random one."""
    return (
        request.headers.get("x-real-ip")
        or (request.client.host if request.client else "unknown")
    )


# ── Client spec (audit 2.1): 5/minute per IP on login, register and verify-otp;
#    after 5 consecutive failures a 15-minute temporary block; log repeated attempts.
IP_PER_MINUTE = (5, 60)
LOCKOUT_FAILURES = 5
LOCKOUT_SECONDS = 15 * 60
OTP_REQUEST_PER_EMAIL = (5, 15 * 60)      # register / forgot-password / resend


def _mask(key: str) -> str:
    """Keep logs useful without writing whole email addresses into them."""
    kind, _, ident = key.partition(":")
    if "@" in ident:
        name, _, domain = ident.partition("@")
        ident = f"{name[:2]}***@{domain}"
    return f"{kind}:{ident}"


def _aware(dt):
    return dt if dt is None or dt.tzinfo else dt.replace(tzinfo=timezone.utc)


async def check_lockout(key: str) -> None:
    """Raise 429 while `key` (an email) is locked out after too many failures."""
    doc = await RateLimitBucket.get_motor_collection().find_one({"key": f"lock:{key}"})
    if not doc or doc.get("hits", 0) < LOCKOUT_FAILURES:
        return
    left = int((_aware(doc["expires_at"]) - datetime.now(timezone.utc)).total_seconds())
    if left <= 0:
        return  # expired; the TTL index will remove it shortly
    logger.warning("Locked out | %s | %ss left", _mask(key), left)
    raise RateLimitException(
        "Too many failed attempts. Please try again in 15 minutes.",
        headers={"Retry-After": str(left)},
    )


async def record_failure(key: str, ip: str | None = None) -> None:
    """Count one failed attempt on `key`. The 5th failure starts a 15-minute
    lockout; a lapsed counter starts again from zero (so failures must be
    consecutive within the window)."""
    coll = RateLimitBucket.get_motor_collection()
    now = datetime.now(timezone.utc)
    doc = await coll.find_one({"key": f"lock:{key}"})
    if doc and _aware(doc["expires_at"]) <= now:
        await coll.delete_one({"key": f"lock:{key}"})
    doc = await coll.find_one_and_update(
        {"key": f"lock:{key}"},
        {
            "$inc": {"hits": 1},
            "$set": {"expires_at": now + timedelta(seconds=LOCKOUT_SECONDS)},
        },
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    n = doc["hits"]
    if n >= 2:  # a single typo is normal; repeated ones are worth a log line
        logger.warning(
            "Failed auth attempt #%s | %s | ip=%s%s", n, _mask(key), ip or "?",
            " | LOCKED OUT" if n >= LOCKOUT_FAILURES else "",
        )


async def clear_failures(key: str) -> None:
    """A success ends the streak (failures must be CONSECUTIVE to lock)."""
    await RateLimitBucket.get_motor_collection().delete_one({"key": f"lock:{key}"})


async def guard_login(email: str, ip: str | None = None) -> None:
    if ip:
        await hit(f"login-ip:{ip}", *IP_PER_MINUTE)
    await check_lockout(f"login:{email.lower()}")


async def guard_otp_request(email: str, ip: str | None = None, kind: str = "otp") -> None:
    await hit(f"otp-req:{email.lower()}", *OTP_REQUEST_PER_EMAIL)
    if ip:
        await hit(f"{kind}-ip:{ip}", *IP_PER_MINUTE)


async def guard_otp_verify(email: str, ip: str | None = None) -> None:
    if ip:
        await hit(f"otp-verify-ip:{ip}", *IP_PER_MINUTE)
    await check_lockout(f"otp:{email.lower()}")

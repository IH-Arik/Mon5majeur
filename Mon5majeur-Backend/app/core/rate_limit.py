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
    """Real client IP behind nginx (X-Forwarded-For first hop, else X-Real-IP)."""
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.headers.get("x-real-ip") or (request.client.host if request.client else "unknown")


# Named limits: (limit, window seconds)
LOGIN_PER_EMAIL = (10, 15 * 60)
LOGIN_PER_IP = (30, 60)
OTP_REQUEST_PER_EMAIL = (5, 15 * 60)      # register / forgot-password / resend
OTP_VERIFY_PER_EMAIL = (10, 15 * 60)
AUTH_PER_IP = (30, 60)


async def guard_login(email: str, ip: str | None = None) -> None:
    await hit(f"login:{email.lower()}", *LOGIN_PER_EMAIL)
    if ip:
        await hit(f"login-ip:{ip}", *LOGIN_PER_IP)


async def guard_otp_request(email: str, ip: str | None = None) -> None:
    await hit(f"otp-req:{email.lower()}", *OTP_REQUEST_PER_EMAIL)
    if ip:
        await hit(f"auth-ip:{ip}", *AUTH_PER_IP)


async def guard_otp_verify(email: str, ip: str | None = None) -> None:
    await hit(f"otp-verify:{email.lower()}", *OTP_VERIFY_PER_EMAIL)
    if ip:
        await hit(f"auth-ip:{ip}", *AUTH_PER_IP)

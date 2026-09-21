"""
OTP verification with a hard cap on guesses (audit 2.1).

A 6-digit code has only 1,000,000 possibilities and stays valid for 15
minutes, so without a cap a script can simply try them all. Every check now
spends one of MAX_OTP_ATTEMPTS attempts on the user's live OTP *before* the
code is compared, in a single atomic Mongo update, so the cap holds however
many requests race each other. When the attempts are used up the OTP is
deleted and the user has to request a new one.
"""
from __future__ import annotations

import hmac

from pymongo import ReturnDocument

from app.core import rate_limit
from app.exceptions.errors import BadRequestException
from app.modules.auth.model import OTPToken

MAX_OTP_ATTEMPTS = 5


async def validate_otp(user, code: str, purpose: str, *, consume: bool) -> OTPToken:
    """Validate `code` for `user`. `consume=False` is the "peek" used by the
    two-step forgot-password flow (it still costs an attempt). Raises
    BadRequestException on any failure; 5 consecutive failures for an account
    also start a 15-minute lockout (429), across codes."""
    lock_key = f"otp:{(getattr(user, 'email', '') or str(user.id)).lower()}"
    await rate_limit.check_lockout(lock_key)

    try:
        token = await _validate(user, code, purpose, consume=consume)
    except BadRequestException:
        await rate_limit.record_failure(lock_key)
        raise
    await rate_limit.clear_failures(lock_key)
    return token


async def _validate(user, code: str, purpose: str, *, consume: bool) -> OTPToken:
    coll = OTPToken.get_motor_collection()
    doc = await coll.find_one_and_update(
        {
            "user_id": user.id,
            "purpose": purpose,
            "$or": [
                {"failed_attempts": {"$lt": MAX_OTP_ATTEMPTS}},
                {"failed_attempts": {"$exists": False}},
            ],
        },
        {"$inc": {"failed_attempts": 1}},
        sort=[("created_at", -1)],
        return_document=ReturnDocument.AFTER,
    )

    if doc is None:
        # No live OTP, or its attempts are already spent — drop any leftover
        # so the user must ask for a fresh code.
        await coll.delete_many({"user_id": user.id, "purpose": purpose})
        raise BadRequestException(
            "Too many attempts or no active code. Please request a new code"
        )

    token = await OTPToken.get(doc["_id"])
    if token is None:
        raise BadRequestException("Invalid verification code")

    if token.is_expired:
        await token.delete()
        raise BadRequestException("Verification code has expired. Please request a new one")

    if not hmac.compare_digest(str(token.code), str(code or "")):
        if doc.get("failed_attempts", 0) >= MAX_OTP_ATTEMPTS:
            await token.delete()
            raise BadRequestException("Too many attempts. Please request a new code")
        raise BadRequestException("Invalid verification code")

    if consume:
        await token.delete()
    return token

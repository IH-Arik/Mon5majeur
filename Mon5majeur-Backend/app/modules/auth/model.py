from datetime import datetime, timedelta, timezone
from typing import Literal

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


def _expire_in_15min() -> datetime:
    return datetime.now(timezone.utc) + timedelta(minutes=15)


class OTPToken(BaseDocument):
    """
    One-time password token used for:
      - email verification after registration
      - password reset flow
    Expires in 15 minutes. Deleted on use.
    """
    user_id: PydanticObjectId
    email: str
    code: str                            # 6-digit string
    purpose: Literal["verify_email", "reset_password"]
    expires_at: datetime = None          # set by validator

    def __init__(self, **data):
        if "expires_at" not in data:
            data["expires_at"] = _expire_in_15min()
        super().__init__(**data)

    @property
    def is_expired(self) -> bool:
        return datetime.now(timezone.utc) > self.expires_at.replace(tzinfo=timezone.utc)

    class Settings:
        name = "otp_tokens"
        indexes = [
            IndexModel([("user_id", ASCENDING)]),
            IndexModel([("email", ASCENDING), ("purpose", ASCENDING)]),
            # TTL index — MongoDB auto-deletes after expiry
            IndexModel([("expires_at", ASCENDING)], expireAfterSeconds=0),
        ]


class RefreshToken(BaseDocument):
    """Stores issued refresh tokens for revocation support."""
    user_id: PydanticObjectId
    token_hash: str
    is_revoked: bool = False

    class Settings:
        name = "refresh_tokens"
        indexes = [
            IndexModel([("user_id", ASCENDING)]),
            IndexModel([("token_hash", ASCENDING)], unique=True),
        ]

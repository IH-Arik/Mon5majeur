from datetime import date, datetime
from typing import Literal

from beanie import Indexed
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


def derive_user_status(*, is_banned: bool, is_active: bool, is_verified: bool) -> str:
    """Pure so it's testable without spinning up a Beanie-initialized DB."""
    if is_banned:
        return "Banned"
    if not is_active:
        return "Inactive"
    if not is_verified:
        return "Pending"
    return "Active"


class User(BaseDocument):
    email: Indexed(str, unique=True)  # type: ignore[valid-type]
    hashed_password: str | None = None          # None for OAuth-only accounts
    full_name: str | None = None
    avatar_url: str | None = None

    language: Literal["en", "fr"] = "en"

    is_active: bool = True
    is_superuser: bool = False
    is_verified: bool = False
    is_banned: bool = False  # admin action — distinct from is_active, which
    # also goes False when a user soft-deletes their own account (see
    # profile_router.delete_account). Keeping them separate means the
    # dashboard can tell "banned by admin" apart from "deleted by user".

    auth_provider: Literal["email", "google", "apple"] = "email"
    google_id: str | None = None
    apple_id: str | None = None

    # Sequential integer ID — used as team_id in Flutter compat responses (int? type)
    auto_id: int | None = None

    # ── Profile completion ────────────────────────────────────────────────────
    team_logo: str | None = None           # slug from TEAM_LOGOS list
    team_name: str | None = None
    favourite_team: str | None = None      # NBA team name
    date_of_birth: date | None = None
    terms_accepted: bool = False
    push_notifications_enabled: bool = False
    notification_types: list[str] = []     # e.g. ["team_reminder", "results"]
    is_profile_complete: bool = False

    # Token economy
    token_balance: int = 0                   # in-app tokens earned/spent
    last_daily_video_claim: datetime | None = None  # UTC; daily ad-reward throttle

    # Premium live score access
    premium_until: datetime | None = None    # UTC; None = no premium

    # FCM push token (updated by mobile app on login/refresh)
    fcm_token: str | None = None

    @property
    def status(self) -> str:
        """Single display status for the admin dashboard, derived rather
        than stored so it can never drift out of sync with the flags above."""
        return derive_user_status(
            is_banned=self.is_banned, is_active=self.is_active, is_verified=self.is_verified
        )

    class Settings:
        name = "users"
        indexes = [
            IndexModel([("email", ASCENDING)], unique=True),
            IndexModel([("google_id", ASCENDING)], sparse=True),
            IndexModel([("apple_id", ASCENDING)], sparse=True),
            IndexModel([("auto_id", ASCENDING)], sparse=True),
        ]

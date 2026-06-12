from datetime import date, datetime
from typing import Literal

from beanie import Indexed
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class User(BaseDocument):
    email: Indexed(str, unique=True)  # type: ignore[valid-type]
    hashed_password: str | None = None          # None for OAuth-only accounts
    full_name: str | None = None
    avatar_url: str | None = None

    language: Literal["en", "fr"] = "en"

    is_active: bool = True
    is_superuser: bool = False
    is_verified: bool = False

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

    # Premium live score access
    premium_until: datetime | None = None    # UTC; None = no premium

    # FCM push token (updated by mobile app on login/refresh)
    fcm_token: str | None = None

    class Settings:
        name = "users"
        indexes = [
            IndexModel([("email", ASCENDING)], unique=True),
            IndexModel([("google_id", ASCENDING)], sparse=True),
            IndexModel([("apple_id", ASCENDING)], sparse=True),
            IndexModel([("auto_id", ASCENDING)], sparse=True),
        ]

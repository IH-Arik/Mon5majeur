from datetime import date, datetime
from typing import Annotated, Literal

from beanie import PydanticObjectId
from pydantic import EmailStr, StringConstraints, field_validator

from app.modules.users.constants import NBA_TEAMS, NOTIFICATION_TYPE_SLUGS, TEAM_LOGO_SLUGS
from app.shared.base_schema import BaseSchema

StrongPassword = Annotated[str, StringConstraints(min_length=8, max_length=128)]

UserStatus = Literal["Active", "Pending", "Banned", "Inactive"]


# ── Profile update (partial — existing PATCH /me) ────────────────────────────

class UserUpdate(BaseSchema):
    full_name: str | None = None
    avatar_url: str | None = None
    language: Literal["en", "fr"] | None = None


class UserAdminUpdate(UserUpdate):
    is_active: bool | None = None
    is_superuser: bool | None = None
    is_verified: bool | None = None
    is_banned: bool | None = None


# ── Complete profile (onboarding flow) ───────────────────────────────────────

class CompleteProfileRequest(BaseSchema):
    team_logo: str
    team_name: Annotated[str, StringConstraints(min_length=1, max_length=50)]
    favourite_team: str
    date_of_birth: date
    terms_accepted: bool
    push_notifications_enabled: bool = False
    notification_types: list[str] = []

    @field_validator("team_logo")
    @classmethod
    def validate_logo(cls, v: str) -> str:
        if v not in TEAM_LOGO_SLUGS:
            raise ValueError(f"Invalid team logo. Choose from: {sorted(TEAM_LOGO_SLUGS)}")
        return v

    @field_validator("favourite_team")
    @classmethod
    def validate_team(cls, v: str) -> str:
        if v not in NBA_TEAMS:
            raise ValueError("Invalid favourite team name")
        return v

    @field_validator("notification_types")
    @classmethod
    def validate_notification_types(cls, v: list[str]) -> list[str]:
        invalid = set(v) - NOTIFICATION_TYPE_SLUGS
        if invalid:
            raise ValueError(f"Invalid notification types: {invalid}")
        return v

    @field_validator("terms_accepted")
    @classmethod
    def must_accept_terms(cls, v: bool) -> bool:
        if not v:
            raise ValueError("You must accept the Terms & Conditions")
        return v

    @field_validator("date_of_birth")
    @classmethod
    def validate_dob(cls, v: date) -> date:
        from datetime import date as date_type
        today = date_type.today()
        age = today.year - v.year - ((today.month, today.day) < (v.month, v.day))
        if age < 13:
            raise ValueError("You must be at least 13 years old")
        if v > today:
            raise ValueError("Date of birth cannot be in the future")
        return v


# ── Responses ─────────────────────────────────────────────────────────────────

class UserResponse(BaseSchema):
    id: PydanticObjectId
    email: EmailStr
    full_name: str | None
    avatar_url: str | None
    language: str
    is_active: bool
    is_superuser: bool
    is_verified: bool
    is_banned: bool = False
    status: UserStatus
    auth_provider: str
    # profile completion fields
    team_logo: str | None = None
    team_name: str | None = None
    favourite_team: str | None = None
    date_of_birth: date | None = None
    terms_accepted: bool = False
    push_notifications_enabled: bool = False
    notification_types: list[str] = []
    is_profile_complete: bool = False
    # Additive fields for the admin detail view — safe for existing
    # consumers (Flutter's own /me call) since they simply ignore the extras.
    created_at: datetime
    token_balance: int = 0
    premium_until: datetime | None = None
    created_at: datetime
    updated_at: datetime


class UserPublicResponse(BaseSchema):
    """Minimal public profile — safe to expose to other users."""
    id: PydanticObjectId
    full_name: str | None
    avatar_url: str | None
    team_logo: str | None = None
    team_name: str | None = None


# ── Misc requests ─────────────────────────────────────────────────────────────

class LanguageUpdateRequest(BaseSchema):
    language: Literal["en", "fr"]


# ── Config endpoints response ─────────────────────────────────────────────────

class TeamLogoItem(BaseSchema):
    slug: str
    label: str


class NBATeamListResponse(BaseSchema):
    teams: list[str]


class NotificationTypeItem(BaseSchema):
    slug: str
    label: str


# ── Admin dashboard ───────────────────────────────────────────────────────────

class UserStatsResponse(BaseSchema):
    total_users: int
    new_signups_30d: int
    monthly_active_users: int  # distinct users with ≥1 validated lineup in the last 30 days
    banned_users: int

from typing import Annotated, Any

from pydantic import EmailStr, StringConstraints, field_validator, model_validator

from app.shared.base_schema import BaseSchema

StrongPassword = Annotated[str, StringConstraints(min_length=8, max_length=128)]


# ── Register ──────────────────────────────────────────────────────────────────

class RegisterRequest(BaseSchema):
    email: EmailStr
    password: StrongPassword
    confirm_password: str
    full_name: str | None = None
    language: str = "en"

    @field_validator("confirm_password")
    @classmethod
    def passwords_match(cls, v: str, info) -> str:
        if info.data.get("password") and v != info.data["password"]:
            raise ValueError("Passwords do not match")
        return v


# ── Login ─────────────────────────────────────────────────────────────────────

class LoginRequest(BaseSchema):
    email: EmailStr
    password: str


# ── User info & Tokens ────────────────────────────────────────────────────────

class AuthUserInfo(BaseSchema):
    id: int | None = None
    email: str = ""
    full_name: str | None = None
    avatar_url: str | None = None
    is_profile_complete: bool = False


class TokenResponse(BaseSchema):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access: str | None = None
    refresh: str | None = None
    user: AuthUserInfo | None = None


class RefreshRequest(BaseSchema):
    refresh_token: str


# ── OAuth ─────────────────────────────────────────────────────────────────────

class GoogleOAuthRequest(BaseSchema):
    id_token: str | None = None
    token: str | None = None

    @model_validator(mode="before")
    @classmethod
    def validate_token_present(cls, values: Any) -> Any:
        if isinstance(values, dict):
            id_token = values.get("id_token") or values.get("token")
            if not id_token or not str(id_token).strip():
                raise ValueError("Either 'id_token' or 'token' must be provided.")
            values["id_token"] = str(id_token).strip()
        return values


class AppleOAuthRequest(BaseSchema):
    identity_token: str
    full_name: str | None = None


# ── Password management ───────────────────────────────────────────────────────

class ChangePasswordRequest(BaseSchema):
    current_password: str
    new_password: StrongPassword
    confirm_new_password: str

    @field_validator("confirm_new_password")
    @classmethod
    def passwords_match(cls, v: str, info) -> str:
        if info.data.get("new_password") and v != info.data["new_password"]:
            raise ValueError("Passwords do not match")
        return v


class ForgotPasswordRequest(BaseSchema):
    email: EmailStr


class VerifyOTPRequest(BaseSchema):
    email: EmailStr
    code: str = Annotated[str, StringConstraints(min_length=6, max_length=6)]


class ResetPasswordRequest(BaseSchema):
    email: EmailStr
    code: str
    new_password: StrongPassword
    confirm_new_password: str

    @field_validator("confirm_new_password")
    @classmethod
    def passwords_match(cls, v: str, info) -> str:
        if info.data.get("new_password") and v != info.data["new_password"]:
            raise ValueError("Passwords do not match")
        return v


# ── Email verification ────────────────────────────────────────────────────────

class VerifyEmailRequest(BaseSchema):
    email: EmailStr
    code: str


class ResendVerificationRequest(BaseSchema):
    email: EmailStr

from typing import Annotated

from pydantic import EmailStr, StringConstraints, field_validator

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


# ── Tokens ────────────────────────────────────────────────────────────────────

class TokenResponse(BaseSchema):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseSchema):
    refresh_token: str


# ── OAuth ─────────────────────────────────────────────────────────────────────

class GoogleOAuthRequest(BaseSchema):
    id_token: str


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

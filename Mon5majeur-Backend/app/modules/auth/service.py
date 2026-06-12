import random
import string

import httpx
from beanie import PydanticObjectId
from jose import JWTError, jwt

from app.core.config import settings
from app.core.logging import get_logger
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.exceptions.errors import BadRequestException, NotFoundException, UnauthorizedException
from app.modules.auth.constants import GOOGLE_TOKEN_INFO_URL, SUPPORTED_LANGUAGES
from app.modules.auth.model import OTPToken
from app.modules.auth.schema import (
    AppleOAuthRequest,
    ChangePasswordRequest,
    ForgotPasswordRequest,
    GoogleOAuthRequest,
    LoginRequest,
    RegisterRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.modules.users.model import User
from app.modules.users.repository import UserRepository
from app.utils.email import send_otp_email

logger = get_logger(__name__)


def _make_tokens(user_id: str) -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
    )


def _generate_otp(length: int = 6) -> str:
    return "".join(random.choices(string.digits, k=length))


class AuthService:
    def __init__(self, user_repo: UserRepository) -> None:
        self.user_repo = user_repo

    # ── Register ──────────────────────────────────────────────────────────────

    async def register(self, payload: RegisterRequest) -> TokenResponse:
        if await self.user_repo.email_exists(payload.email):
            raise BadRequestException("Email already registered")
        if payload.language not in SUPPORTED_LANGUAGES:
            raise BadRequestException(f"Language must be one of {SUPPORTED_LANGUAGES}")

        user = await self.user_repo.create(
            email=payload.email,
            hashed_password=hash_password(payload.password),
            full_name=payload.full_name,
            language=payload.language,
        )

        # Send email verification OTP
        await self._create_and_send_otp(user, "verify_email")

        return _make_tokens(str(user.id))

    # ── Login ─────────────────────────────────────────────────────────────────

    async def login(self, payload: LoginRequest) -> TokenResponse:
        user = await self.user_repo.get_by_email(payload.email)
        if not user or not verify_password(payload.password, user.hashed_password or ""):
            raise UnauthorizedException("Invalid email or password")
        if not user.is_active:
            raise UnauthorizedException("Account is inactive")
        return _make_tokens(str(user.id))

    # ── Refresh ───────────────────────────────────────────────────────────────

    async def refresh(self, refresh_token: str) -> TokenResponse:
        try:
            payload = decode_token(refresh_token)
            if payload.get("type") != "refresh":
                raise UnauthorizedException("Invalid token type")
            user_id = payload["sub"]
        except JWTError:
            raise UnauthorizedException("Invalid or expired refresh token")

        user = await self.user_repo.get(PydanticObjectId(user_id))
        if not user or not user.is_active:
            raise UnauthorizedException("User not found or inactive")
        return _make_tokens(user_id)

    # ── Email verification ────────────────────────────────────────────────────

    async def verify_email(self, payload: VerifyEmailRequest) -> dict:
        user = await self.user_repo.get_by_email(payload.email)
        if not user:
            raise NotFoundException("User not found")
        if user.is_verified:
            return {"detail": "Email already verified"}

        await self._validate_otp(user, payload.code, "verify_email")
        await user.save_updated(is_verified=True)
        return {"detail": "Email verified successfully"}

    async def resend_verification(self, payload: ResendVerificationRequest) -> dict:
        user = await self.user_repo.get_by_email(payload.email)
        if not user:
            # Don't reveal if email exists
            return {"detail": "If this email is registered, a verification code has been sent"}
        if user.is_verified:
            raise BadRequestException("Email is already verified")

        # Delete old OTPs for this user/purpose
        await OTPToken.find(
            OTPToken.user_id == user.id,
            OTPToken.purpose == "verify_email",
        ).delete()

        await self._create_and_send_otp(user, "verify_email")
        return {"detail": "Verification code sent"}

    # ── Forgot / Reset password ───────────────────────────────────────────────

    async def forgot_password(self, payload: ForgotPasswordRequest) -> dict:
        user = await self.user_repo.get_by_email(payload.email)
        if user and user.is_active:
            # Delete any existing reset OTPs
            await OTPToken.find(
                OTPToken.user_id == user.id,
                OTPToken.purpose == "reset_password",
            ).delete()

            await self._create_and_send_otp(user, "reset_password")

        # Always return same response — don't reveal if email exists
        return {"detail": "If this email is registered, a reset code has been sent"}

    async def reset_password(self, payload: ResetPasswordRequest) -> dict:
        user = await self.user_repo.get_by_email(payload.email)
        if not user:
            raise BadRequestException("Invalid request")

        await self._validate_otp(user, payload.code, "reset_password")
        await user.save_updated(hashed_password=hash_password(payload.new_password))
        return {"detail": "Password has been reset successfully"}

    # ── Change password (authenticated) ──────────────────────────────────────

    async def change_password(self, user: User, payload: ChangePasswordRequest) -> dict:
        if not verify_password(payload.current_password, user.hashed_password or ""):
            raise BadRequestException("Current password is incorrect")
        await user.save_updated(hashed_password=hash_password(payload.new_password))
        return {"detail": "Password changed successfully"}

    # ── Google OAuth ──────────────────────────────────────────────────────────

    async def google_oauth(self, payload: GoogleOAuthRequest) -> TokenResponse:
        async with httpx.AsyncClient() as client:
            resp = await client.get(GOOGLE_TOKEN_INFO_URL, params={"id_token": payload.id_token})

        if resp.status_code != 200:
            raise UnauthorizedException("Invalid Google token")

        data = resp.json()
        if data.get("aud") != settings.SOCIAL_AUTH_GOOGLE_CLIENT_ID:
            raise UnauthorizedException("Google token audience mismatch")

        email = data.get("email")
        if not email:
            raise UnauthorizedException("Google token missing email")

        user = await self.user_repo.get_by_email(email)
        if not user:
            user = await self.user_repo.create(
                email=email,
                hashed_password=None,
                full_name=data.get("name"),
                avatar_url=data.get("picture"),
                is_verified=True,
                auth_provider="google",
                google_id=data.get("sub"),
            )
        elif not user.google_id:
            await user.save_updated(google_id=data.get("sub"), auth_provider="google", is_verified=True)

        return _make_tokens(str(user.id))

    # ── Apple OAuth ───────────────────────────────────────────────────────────

    async def apple_oauth(self, payload: AppleOAuthRequest) -> TokenResponse:
        try:
            unverified = jwt.get_unverified_claims(payload.identity_token)
            apple_user_id = unverified.get("sub")
            email = unverified.get("email")
        except JWTError:
            raise UnauthorizedException("Invalid Apple identity token")

        if not apple_user_id:
            raise UnauthorizedException("Apple token missing subject")

        user = await self.user_repo.get_by_apple_id(apple_user_id)
        if not user:
            if not email:
                raise UnauthorizedException("Apple token missing email — required for first login")
            user = await self.user_repo.create(
                email=email,
                hashed_password=None,
                full_name=payload.full_name,
                is_verified=True,
                auth_provider="apple",
                apple_id=apple_user_id,
            )
        return _make_tokens(str(user.id))

    # ── Internal helpers ──────────────────────────────────────────────────────

    async def _create_and_send_otp(self, user: User, purpose: str) -> str:
        code = _generate_otp()
        await OTPToken(
            user_id=user.id,
            email=user.email,
            code=code,
            purpose=purpose,
        ).insert()

        send_otp_email(user.email, code, purpose)
        logger.info("OTP created | user=%s | purpose=%s | code=%s", user.email, purpose, code)
        return code

    async def _validate_otp(self, user: User, code: str, purpose: str) -> OTPToken:
        token = await OTPToken.find_one(
            OTPToken.user_id == user.id,
            OTPToken.code == code,
            OTPToken.purpose == purpose,
        )

        if not token:
            raise BadRequestException("Invalid verification code")
        if token.is_expired:
            await token.delete()
            raise BadRequestException("Verification code has expired. Please request a new one")

        # Consume OTP — delete after use
        await token.delete()
        return token

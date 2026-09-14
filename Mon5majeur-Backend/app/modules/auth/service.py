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
from app.database.counters import next_seq
from app.exceptions.errors import BadRequestException, NotFoundException, UnauthorizedException
from app.modules.auth.constants import GOOGLE_TOKEN_INFO_URL, SUPPORTED_LANGUAGES
from app.modules.auth.model import OTPToken
from app.modules.auth.schema import (
    AppleOAuthRequest,
    AuthUserInfo,
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


def _make_tokens(user_id: str, user: User | None = None) -> TokenResponse:
    access = create_access_token(user_id)
    refresh = create_refresh_token(user_id)
    user_info = None
    if user:
        user_info = AuthUserInfo(
            id=getattr(user, "auto_id", None),
            email=getattr(user, "email", ""),
            full_name=getattr(user, "full_name", None),
            avatar_url=getattr(user, "avatar_url", None),
            is_profile_complete=getattr(user, "is_profile_complete", False),
        )
    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        token_type="bearer",
        access=access,
        refresh=refresh,
        user=user_info,
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

        return _make_tokens(str(user.id), user)

    # ── Login ─────────────────────────────────────────────────────────────────

    async def login(self, payload: LoginRequest) -> TokenResponse:
        user = await self.user_repo.get_by_email(payload.email)
        if not user or not verify_password(payload.password, getattr(user, "hashed_password", "") or ""):
            raise UnauthorizedException("Invalid email or password")
        if getattr(user, "is_banned", False):
            raise UnauthorizedException("This account has been banned")
        if not getattr(user, "is_active", True):
            raise UnauthorizedException("Account is inactive")
        return _make_tokens(str(user.id), user)

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
        if user.is_banned:
            raise UnauthorizedException("This account has been banned")
        return _make_tokens(user_id, user)

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
        id_token = payload.id_token
        if not id_token:
            raise BadRequestException("Google ID token is required")

        # 1. Fetch tokeninfo from Google
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(GOOGLE_TOKEN_INFO_URL, params={"id_token": id_token})
        except httpx.RequestError as exc:
            logger.error("Failed to connect to Google OAuth service: %s", exc)
            raise UnauthorizedException("Could not connect to Google authentication service")

        if resp.status_code != 200:
            logger.warning("Google token validation failed: status=%s, body=%s", resp.status_code, resp.text)
            raise UnauthorizedException("Invalid or expired Google token")

        try:
            data = resp.json()
        except Exception:
            raise UnauthorizedException("Invalid response from Google verification service")

        # 2. Check token issuer
        iss = data.get("iss", "")
        if iss not in ("accounts.google.com", "https://accounts.google.com"):
            logger.warning("Google token issuer mismatch: %s", iss)
            raise UnauthorizedException("Invalid Google token issuer")

        # 3. Audience & Authorized Party check
        allowed_ids = settings.allowed_google_client_ids
        token_aud = data.get("aud")
        token_azp = data.get("azp")
        if allowed_ids:
            if token_aud not in allowed_ids and token_azp not in allowed_ids:
                logger.warning(
                    "Google token audience mismatch. aud=%s, azp=%s, allowed=%s",
                    token_aud,
                    token_azp,
                    allowed_ids,
                )
                raise UnauthorizedException("Google token audience mismatch")

        # 4. Email verification
        email = data.get("email")
        if not email:
            raise UnauthorizedException("Google account has no email")

        email_verified = data.get("email_verified")
        if email_verified not in (True, "true", "True", 1, "1"):
            raise UnauthorizedException("Google email address is not verified")

        email = email.lower().strip()
        google_id = data.get("sub")
        full_name = data.get("name") or (f"{data.get('given_name', '')} {data.get('family_name', '')}".strip() or None)
        avatar_url = data.get("picture")

        # 5. User lookup & linking: first by google_id, then by email
        user: User | None = None
        if google_id:
            user = await self.user_repo.get_by_google_id(google_id)
        if not user:
            user = await self.user_repo.get_by_email(email)

        if user:
            # Check account active / banned status
            if getattr(user, "is_banned", False):
                raise UnauthorizedException("This account has been banned")
            if not getattr(user, "is_active", True):
                raise UnauthorizedException("Account is inactive")

            updates: dict = {}
            if not getattr(user, "google_id", None) and google_id:
                updates["google_id"] = google_id
            if getattr(user, "auth_provider", None) != "google" and not getattr(user, "hashed_password", None):
                updates["auth_provider"] = "google"
            if not getattr(user, "is_verified", False):
                updates["is_verified"] = True
            if not getattr(user, "full_name", None) and full_name:
                updates["full_name"] = full_name
            if not getattr(user, "avatar_url", None) and avatar_url:
                updates["avatar_url"] = avatar_url
            if getattr(user, "auto_id", None) is None:
                user.auto_id = await next_seq("users")
                updates["auto_id"] = user.auto_id

            if updates:
                await user.save_updated(**updates)
        else:
            locale = data.get("locale", "en")
            lang = "fr" if str(locale).lower().startswith("fr") else "en"
            user = await self.user_repo.create(
                email=email,
                hashed_password=None,
                full_name=full_name,
                avatar_url=avatar_url,
                language=lang,
                is_verified=True,
                auth_provider="google",
                google_id=google_id,
            )

        logger.info("Google login successful | user_id=%s | email=%s", user.id, user.email)
        return _make_tokens(str(user.id), user)

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
        return _make_tokens(str(user.id), user)

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

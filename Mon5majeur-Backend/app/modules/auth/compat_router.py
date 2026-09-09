"""
Flutter-compat auth router.
Mounted at /api (no /v1 prefix) to match Flutter's hardcoded URLs in api_url.dart:

  POST /api/auth/register/                      → register + send OTP
  POST /api/auth/verify-otp/                    → verify registration OTP
  POST /api/auth/login/                         → login {access, refresh, user{id,email}}
  POST /api/auth/forgot-password/               → send reset OTP
  POST /api/auth/verify-forgot-password-otp/   → validate reset OTP (non-consuming)
  POST /api/auth/change-password/               → reset password (no auth — post OTP flow)
"""
import httpx
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, EmailStr

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from app.exceptions.errors import BadRequestException, UnauthorizedException
from app.modules.auth.model import OTPToken
from app.modules.auth.service import AuthService, _generate_otp
from app.modules.auth.dependencies import get_auth_service, get_current_user
from app.modules.users.model import User
from app.utils.email import send_otp_email

router = APIRouter(prefix="/auth", tags=["Auth (Flutter compat)"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class FlutterRegisterRequest(BaseModel):
    email: EmailStr
    password: str
    password2: str          # Flutter sends "password2" not "confirm_password"


class FlutterVerifyOtpRequest(BaseModel):
    email: EmailStr
    otp: str                # Flutter sends "otp" not "code"


class FlutterLoginRequest(BaseModel):
    email: EmailStr
    password: str


class FlutterForgotPasswordRequest(BaseModel):
    email: EmailStr


class FlutterVerifyForgotOtpRequest(BaseModel):
    email: EmailStr
    otp: str


class FlutterChangePasswordRequest(BaseModel):
    """POST /api/auth/change-password/ — called after forgot-password OTP verified. No auth.

    `otp` is required and re-checked here. The earlier verify step leaves no
    trace on the token, so this endpoint is the only place that can prove the
    caller actually holds the code — without it, knowing an email would be
    enough to take over the account.
    """
    email: EmailStr
    otp: str
    new_password: str
    confirm_password: str


class FlutterChangePasswordAuthRequest(BaseModel):
    """POST /api/auth/change-password-auth/ — called from Settings > Change Password (logged in)."""
    old_password: str
    new_password: str
    confirm_new_password: str


class FlutterGoogleAuthRequest(BaseModel):
    """POST /api/auth/google/ — Flutter sends id_token from google_sign_in package."""
    id_token: str


class LoginUserInfo(BaseModel):
    id: int | None = None
    email: str = ""


class FlutterLoginResponse(BaseModel):
    access: str
    refresh: str
    user: LoginUserInfo


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _send_otp(user: User, purpose: str) -> None:
    """Create OTP token and send email."""
    import asyncio
    from app.core.logging import get_logger
    logger = get_logger(__name__)

    await OTPToken.find(
        OTPToken.user_id == user.id,
        OTPToken.purpose == purpose,
    ).delete()

    code = _generate_otp()
    await OTPToken(
        user_id=user.id,
        email=user.email,
        code=code,
        purpose=purpose,
    ).insert()
    # Run synchronous SMTP call in thread pool so it doesn't block the event loop
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, send_otp_email, user.email, code, purpose)
    logger.info("OTP sent | user=%s | purpose=%s", user.email, purpose)


async def _validate_otp_peek(user: User, otp: str, purpose: str) -> OTPToken:
    """Validate OTP but do NOT consume (delete) it — used for 2-step forgot-password flow."""
    token = await OTPToken.find_one(
        OTPToken.user_id == user.id,
        OTPToken.code == otp,
        OTPToken.purpose == purpose,
    )
    if not token:
        raise BadRequestException("Invalid verification code")
    if token.is_expired:
        await token.delete()
        raise BadRequestException("Verification code has expired. Please request a new one")
    return token


async def _validate_and_consume_otp(user: User, otp: str, purpose: str) -> OTPToken:
    """Validate OTP and consume (delete) it."""
    token = await _validate_otp_peek(user, otp, purpose)
    await token.delete()
    return token


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post(
    "/register/",
    status_code=status.HTTP_201_CREATED,
    summary="Register (Flutter: AuthController.signUp)",
)
async def flutter_register(
    payload: FlutterRegisterRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    if payload.password != payload.password2:
        raise BadRequestException("Passwords do not match")
    if len(payload.password) < 6:
        raise BadRequestException("Password must be at least 6 characters")

    repo = service.user_repo
    existing = await repo.get_by_email(payload.email)

    if existing:
        # Resend OTP if user registered but hasn't verified yet
        if not existing.is_verified and existing.is_active:
            await _send_otp(existing, "verify_email")
            return {"message": "OTP resent to your email. Verify to complete registration."}
        raise BadRequestException("Email already registered")

    user = await repo.create(
        email=payload.email,
        hashed_password=hash_password(payload.password),
    )
    await _send_otp(user, "verify_email")
    return {"message": "OTP sent to your email. Verify to complete registration."}


@router.post(
    "/verify-otp/",
    summary="Verify registration OTP (Flutter: AuthController.verifyOtp)",
)
async def flutter_verify_otp(
    payload: FlutterVerifyOtpRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    user = await service.user_repo.get_by_email(payload.email)
    if not user:
        raise BadRequestException("Invalid request")
    if user.is_verified:
        return {"message": "Email already verified"}
    await _validate_and_consume_otp(user, payload.otp, "verify_email")
    await user.save_updated(is_verified=True)
    return {"message": "Registration complete. You can now log in."}


@router.post(
    "/login/",
    response_model=FlutterLoginResponse,
    summary="Login (Flutter: AuthController.login) — returns {access, refresh, user}",
)
async def flutter_login(
    payload: FlutterLoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> FlutterLoginResponse:
    user = await service.user_repo.get_by_email(payload.email)
    if not user or not verify_password(payload.password, user.hashed_password or ""):
        raise UnauthorizedException("Invalid email or password")
    if user.is_banned:
        raise UnauthorizedException("This account has been banned")
    if not user.is_active:
        raise UnauthorizedException("Account is inactive")

    return FlutterLoginResponse(
        access=create_access_token(str(user.id)),
        refresh=create_refresh_token(str(user.id)),
        user=LoginUserInfo(id=user.auto_id, email=user.email),
    )


@router.post(
    "/forgot-password/",
    status_code=status.HTTP_200_OK,
    summary="Forgot password — send OTP (Flutter: AuthController.sendForgotPasswordOtp)",
)
async def flutter_forgot_password(
    payload: FlutterForgotPasswordRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    user = await service.user_repo.get_by_email(payload.email)
    if user and user.is_active:
        await _send_otp(user, "reset_password")
    return {"message": "If this email is registered, a reset code has been sent"}


@router.post(
    "/verify-forgot-password-otp/",
    summary="Verify forgot-password OTP without consuming it (Flutter: AuthController.verifyForgotPasswordOtp)",
)
async def flutter_verify_forgot_otp(
    payload: FlutterVerifyForgotOtpRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    user = await service.user_repo.get_by_email(payload.email)
    if not user:
        raise BadRequestException("Invalid request")
    await _validate_otp_peek(user, payload.otp, "reset_password")
    return {"message": "OTP verified successfully."}


@router.post(
    "/change-password/",
    summary="Reset password after OTP flow (Flutter: AuthController.changePassword — no auth)",
)
async def flutter_change_password(
    payload: FlutterChangePasswordRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    if payload.new_password != payload.confirm_password:
        raise BadRequestException("Passwords do not match")
    if len(payload.new_password) < 6:
        raise BadRequestException("Password must be at least 6 characters")

    user = await service.user_repo.get_by_email(payload.email)
    if not user:
        raise BadRequestException("Invalid request")

    # Re-check the code itself, not merely that some token exists — the peek
    # in verify-forgot-password-otp records nothing, so skipping this would
    # let anyone who triggered a reset for an address complete it.
    await _validate_and_consume_otp(user, payload.otp, "reset_password")
    await user.save_updated(hashed_password=hash_password(payload.new_password))
    return {"message": "Password changed successfully."}


@router.post(
    "/change-password-auth/",
    summary="Change password while logged in (Flutter: ProfileSettings > ChangePasswordScreen)",
)
async def flutter_change_password_auth(
    payload: FlutterChangePasswordAuthRequest,
    current_user: User = Depends(get_current_user),
) -> dict:
    if payload.new_password != payload.confirm_new_password:
        raise BadRequestException("Passwords do not match")
    if not verify_password(payload.old_password, current_user.hashed_password or ""):
        raise BadRequestException("Current password is incorrect")
    if len(payload.new_password) < 6:
        raise BadRequestException("Password must be at least 6 characters")
    await current_user.save_updated(hashed_password=hash_password(payload.new_password))
    return {"detail": "Password changed successfully"}


@router.post(
    "/google/",
    response_model=FlutterLoginResponse,
    summary="Google Sign-In (Flutter: AuthController.loginWithGoogle)",
)
async def flutter_google_auth(
    payload: FlutterGoogleAuthRequest,
    service: AuthService = Depends(get_auth_service),
) -> FlutterLoginResponse:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://www.googleapis.com/oauth2/v3/tokeninfo",
            params={"id_token": payload.id_token},
        )

    if resp.status_code != 200:
        raise UnauthorizedException("Invalid Google token")

    data = resp.json()

    # Validate audience — must match our web client ID
    if data.get("aud") != settings.SOCIAL_AUTH_GOOGLE_CLIENT_ID:
        raise UnauthorizedException("Google token audience mismatch")

    email = data.get("email")
    if not email:
        raise UnauthorizedException("Google account has no email")

    user = await service.user_repo.get_by_email(email)
    if not user:
        user = await service.user_repo.create(
            email=email,
            hashed_password=None,
            is_verified=True,
            auth_provider="google",
            google_id=data.get("sub"),
        )
    elif not user.google_id:
        await user.save_updated(
            google_id=data.get("sub"),
            auth_provider="google",
            is_verified=True,
        )

    return FlutterLoginResponse(
        access=create_access_token(str(user.id)),
        refresh=create_refresh_token(str(user.id)),
        user=LoginUserInfo(id=user.auto_id, email=user.email),
    )

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
from typing import Any

import httpx
from fastapi import APIRouter, Depends, Request, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, EmailStr, model_validator

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from app.core import rate_limit
from app.core.rate_limit import client_ip, guard_login, guard_otp_request, guard_otp_verify
from app.exceptions.errors import BadRequestException, UnauthorizedException
from app.modules.auth.model import OTPToken
from app.modules.auth.schema import AppleOAuthRequest, GoogleOAuthRequest
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
    id_token: str | None = None
    token: str | None = None

    @model_validator(mode="before")
    @classmethod
    def validate_token(cls, values: Any) -> Any:
        if isinstance(values, dict):
            tok = values.get("id_token") or values.get("token")
            if not tok or not str(tok).strip():
                raise ValueError("id_token is required")
            values["id_token"] = str(tok).strip()
        return values


class FlutterAppleAuthRequest(BaseModel):
    """POST /api/auth/apple/ — Flutter sends identity_token from sign_in_with_apple."""
    identity_token: str
    full_name: str | None = None
    email: str | None = None


class LoginUserInfo(BaseModel):
    id: int | None = None
    email: str = ""
    full_name: str | None = None
    avatar_url: str | None = None
    is_profile_complete: bool = False


class FlutterLoginResponse(BaseModel):
    access: str
    refresh: str
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str = "bearer"
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
    """Validate OTP but do NOT consume (delete) it — used for the 2-step
    forgot-password flow. Every check spends one of a small, hard-capped number
    of attempts (see otp_guard.py)."""
    from app.modules.auth.otp_guard import validate_otp

    return await validate_otp(user, otp, purpose, consume=False)


async def _validate_and_consume_otp(user: User, otp: str, purpose: str) -> OTPToken:
    """Validate OTP and consume (delete) it."""
    from app.modules.auth.otp_guard import validate_otp

    return await validate_otp(user, otp, purpose, consume=True)


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post(
    "/register/",
    status_code=status.HTTP_201_CREATED,
    summary="Register (Flutter: AuthController.signUp)",
)
async def flutter_register(
    payload: FlutterRegisterRequest,
    request: Request,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    await guard_otp_request(payload.email, client_ip(request), kind="register")
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
    request: Request,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    await guard_otp_verify(payload.email, client_ip(request))
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
    request: Request,
    service: AuthService = Depends(get_auth_service),
) -> FlutterLoginResponse:
    await guard_login(payload.email, client_ip(request))
    user = await service.user_repo.get_by_email(payload.email)
    if not user or not verify_password(payload.password, user.hashed_password or ""):
        await rate_limit.record_failure(f"login:{payload.email.lower()}", client_ip(request))
        raise UnauthorizedException("Invalid email or password")
    await rate_limit.clear_failures(f"login:{payload.email.lower()}")
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
    request: Request,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    await guard_otp_request(payload.email, client_ip(request), kind="forgot")
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
    request: Request,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    await guard_otp_verify(payload.email, client_ip(request))
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
    request: Request,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    await guard_otp_verify(payload.email, client_ip(request))
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
@router.post(
    "/google",
    response_model=FlutterLoginResponse,
    include_in_schema=False,
)
async def flutter_google_auth(
    payload: FlutterGoogleAuthRequest,
    service: AuthService = Depends(get_auth_service),
) -> FlutterLoginResponse:
    google_req = GoogleOAuthRequest(id_token=payload.id_token)
    token_resp = await service.google_oauth(google_req)
    user_info = LoginUserInfo()
    if token_resp.user:
        user_info = LoginUserInfo(
            id=token_resp.user.id,
            email=token_resp.user.email,
            full_name=token_resp.user.full_name,
            avatar_url=token_resp.user.avatar_url,
            is_profile_complete=token_resp.user.is_profile_complete,
        )
    return FlutterLoginResponse(
        access=token_resp.access or token_resp.access_token,
        refresh=token_resp.refresh or token_resp.refresh_token,
        access_token=token_resp.access_token,
        refresh_token=token_resp.refresh_token,
        token_type=token_resp.token_type,
        user=user_info,
    )


# ── Apple OAuth (Flutter compat) ──────────────────────────────────────────────

@router.post(
    "/apple/",
    response_model=FlutterLoginResponse,
    summary="Apple Sign-In (Flutter: AuthController.loginWithApple)",
)
@router.post(
    "/apple",
    response_model=FlutterLoginResponse,
    include_in_schema=False,
)
async def flutter_apple_auth(
    payload: FlutterAppleAuthRequest,
    service: AuthService = Depends(get_auth_service),
) -> FlutterLoginResponse:
    apple_req = AppleOAuthRequest(
        identity_token=payload.identity_token,
        full_name=payload.full_name,
        email=payload.email,
    )
    token_resp = await service.apple_oauth(apple_req)
    user_info = LoginUserInfo()
    if token_resp.user:
        user_info = LoginUserInfo(
            id=token_resp.user.id,
            email=token_resp.user.email,
            full_name=token_resp.user.full_name,
            avatar_url=token_resp.user.avatar_url,
            is_profile_complete=token_resp.user.is_profile_complete,
        )
    return FlutterLoginResponse(
        access=token_resp.access or token_resp.access_token,
        refresh=token_resp.refresh or token_resp.refresh_token,
        access_token=token_resp.access_token,
        refresh_token=token_resp.refresh_token,
        token_type=token_resp.token_type,
        user=user_info,
    )


@router.post("/apple/callbacks", response_class=HTMLResponse, include_in_schema=False)
@router.post("/apple/callbacks/", response_class=HTMLResponse, include_in_schema=False)
@router.get("/apple/callbacks", response_class=HTMLResponse, include_in_schema=False)
@router.get("/apple/callbacks/", response_class=HTMLResponse, include_in_schema=False)
async def apple_callbacks(request: Request) -> HTMLResponse:
    """Handles Apple OAuth redirect on Android and redirects back to the app using custom intent scheme."""
    import urllib.parse

    params: dict = {}
    if request.method == "POST":
        try:
            form = await request.form()
            params = dict(form)
        except Exception:
            pass
    else:
        params = dict(request.query_params)

    query_string = urllib.parse.urlencode(params)
    package_name = settings.ANDROID_PACKAGE_NAME or "com.mon5majeur.app"
    intent_url = f"intent://callback?{query_string}#Intent;package={package_name};scheme=signinwithapple;end"

    html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0;url={intent_url}">
    <title>Apple Sign-In Redirect</title>
</head>
<body>
    <p>Redirecting to app...</p>
    <script>
        window.location.href = "{intent_url}";
    </script>
</body>
</html>"""
    return HTMLResponse(content=html)

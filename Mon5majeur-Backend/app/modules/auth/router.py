from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_auth_service, get_current_user
from app.modules.auth.schema import (
    AppleOAuthRequest,
    ChangePasswordRequest,
    ForgotPasswordRequest,
    GoogleOAuthRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.modules.auth.service import AuthService
from app.modules.users.model import User

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── Register ──────────────────────────────────────────────────────────────────

@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register with email & password",
    description="Creates account and sends a 6-digit OTP to the email for verification.",
)
async def register(
    payload: RegisterRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    return await service.register(payload)


# ── Login ─────────────────────────────────────────────────────────────────────

@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login with email & password",
)
async def login(
    payload: LoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    return await service.login(payload)


# ── Token refresh ─────────────────────────────────────────────────────────────

@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Refresh access token",
)
async def refresh(
    payload: RefreshRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    return await service.refresh(payload.refresh_token)


# ── Email verification ────────────────────────────────────────────────────────

@router.post(
    "/verify-email",
    summary="Verify email with 6-digit OTP",
    description="User receives a 6-digit code by email after registration. Submit it here.",
)
async def verify_email(
    payload: VerifyEmailRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    return await service.verify_email(payload)


@router.post(
    "/resend-verification",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Resend email verification code",
)
async def resend_verification(
    payload: ResendVerificationRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    return await service.resend_verification(payload)


# ── Forgot / Reset password ───────────────────────────────────────────────────

@router.post(
    "/forgot-password",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Forgot password — send OTP to email",
    description="Sends a 6-digit reset code to the given email address (if registered).",
)
async def forgot_password(
    payload: ForgotPasswordRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    return await service.forgot_password(payload)


@router.post(
    "/reset-password",
    summary="Reset password with OTP code",
    description="Verify the 6-digit code from email and set a new password.",
)
async def reset_password(
    payload: ResetPasswordRequest,
    service: AuthService = Depends(get_auth_service),
) -> dict:
    return await service.reset_password(payload)


# ── Change password (logged in) ───────────────────────────────────────────────

@router.post(
    "/change-password",
    summary="Change password (must be logged in)",
)
async def change_password(
    payload: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> dict:
    return await service.change_password(current_user, payload)


# ── OAuth ─────────────────────────────────────────────────────────────────────

@router.post(
    "/google",
    response_model=TokenResponse,
    summary="Login or register with Google",
    description="Pass the `id_token` returned by Google Sign-In SDK.",
)
async def google_oauth(
    payload: GoogleOAuthRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    return await service.google_oauth(payload)


@router.post(
    "/apple",
    response_model=TokenResponse,
    summary="Login or register with Apple",
    description="Pass the `identityToken` returned by Sign in with Apple SDK.",
)
async def apple_oauth(
    payload: AppleOAuthRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    return await service.apple_oauth(payload)

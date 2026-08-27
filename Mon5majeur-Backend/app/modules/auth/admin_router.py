"""
Admin dashboard auth router. Mounted at /api (mon5majeur-dashboard hardcodes
this base URL), deliberately separate from /api/auth/login/ (Flutter compat).

Why a separate endpoint instead of reusing /api/auth/login/: that endpoint is
shared with the mobile app and issues a token to ANY active user regardless of
role. Reusing it for the admin dashboard meant any player could sign in to the
admin panel with their own player credentials — the token itself is generic
(get_current_superuser re-checks the role from DB on every request, not from
the token), but the dashboard never made that check at login time. This
endpoint rejects non-superusers before a token is ever issued.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr

from app.core.security import create_access_token, create_refresh_token, verify_password
from app.exceptions.errors import UnauthorizedException
from app.modules.auth.dependencies import get_auth_service
from app.modules.auth.service import AuthService

router = APIRouter(prefix="/admin/auth", tags=["Admin Auth (Dashboard)"])


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str


class AdminLoginUserInfo(BaseModel):
    id: int | None = None
    email: str = ""
    team_name: str | None = None


class AdminLoginResponse(BaseModel):
    access: str
    refresh: str
    user: AdminLoginUserInfo


@router.post(
    "/login/",
    response_model=AdminLoginResponse,
    summary="Admin dashboard login — rejects non-superusers before issuing a token",
)
async def admin_login(
    payload: AdminLoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> AdminLoginResponse:
    user = await service.user_repo.get_by_email(payload.email)

    # Same generic message whether the email doesn't exist, the password is
    # wrong, or the account is simply not an admin — don't leak which case it
    # was, that would let someone probe for valid admin emails.
    invalid = UnauthorizedException("Invalid email or password")

    if not user or not verify_password(payload.password, user.hashed_password or ""):
        raise invalid
    if not user.is_active or not user.is_superuser or user.is_banned:
        raise invalid

    return AdminLoginResponse(
        access=create_access_token(str(user.id)),
        refresh=create_refresh_token(str(user.id)),
        user=AdminLoginUserInfo(id=user.auto_id, email=user.email, team_name=user.team_name),
    )

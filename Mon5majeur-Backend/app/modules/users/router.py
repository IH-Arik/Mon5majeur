from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query, status

from app.modules.auth.dependencies import get_current_superuser, get_current_user
from app.modules.users.constants import NBA_TEAMS, NOTIFICATION_TYPES, TEAM_LOGOS
from app.modules.users.dependencies import get_user_service
from app.modules.users.model import User
from app.modules.users.schema import (
    CompleteProfileRequest,
    LanguageUpdateRequest,
    NBATeamListResponse,
    NotificationTypeItem,
    TeamLogoItem,
    UserAdminUpdate,
    UserResponse,
    UserStatsResponse,
    UserUpdate,
)
from app.modules.users.service import UserService
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/users", tags=["Users"])


# ── Config / reference data ───────────────────────────────────────────────────

@router.get(
    "/config/team-logos",
    response_model=list[TeamLogoItem],
    summary="List available team logos",
    description="Returns the predefined logo options shown during profile completion.",
)
async def list_team_logos() -> list[dict]:
    return TEAM_LOGOS


@router.get(
    "/config/nba-teams",
    response_model=NBATeamListResponse,
    summary="List NBA teams for favourite team dropdown",
)
async def list_nba_teams() -> dict:
    return {"teams": NBA_TEAMS}


@router.get(
    "/config/notification-types",
    response_model=list[NotificationTypeItem],
    summary="List notification type options",
)
async def list_notification_types() -> list[dict]:
    return NOTIFICATION_TYPES


# ── Current user endpoints ────────────────────────────────────────────────────

@router.get("/me", response_model=UserResponse, summary="Get my profile")
async def get_me(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@router.post(
    "/me/complete-profile",
    response_model=UserResponse,
    summary="Complete onboarding profile",
    description=(
        "Called once after registration. Sets team logo, team name, "
        "favourite NBA team, date of birth, and notification preferences. "
        "Marks `is_profile_complete=true`. Can be re-submitted to update."
    ),
)
async def complete_profile(
    payload: CompleteProfileRequest,
    current_user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> User:
    return await service.complete_profile(current_user, payload)


@router.patch("/me", response_model=UserResponse, summary="Update my profile")
async def update_me(
    payload: UserUpdate,
    current_user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> User:
    return await service.update_profile(current_user, payload)


@router.patch("/me/language", response_model=UserResponse, summary="Update language preference (en / fr)")
async def update_language(
    payload: LanguageUpdateRequest,
    current_user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> User:
    return await service.update_language(current_user, payload)


@router.post("/me/fcm-token", summary="Register / update FCM push token")
async def update_fcm_token(
    token: str,
    current_user: User = Depends(get_current_user),
) -> dict:
    current_user.fcm_token = token
    await current_user.save()
    return {"detail": "FCM token updated"}


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT, summary="Delete my account")
async def delete_me(
    current_user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> None:
    await service.delete_user(current_user.id)


# ── Admin endpoints ───────────────────────────────────────────────────────────

@router.get("", response_model=Page[UserResponse], summary="List all users (admin)", dependencies=[Depends(get_current_superuser)])
async def list_users(
    search: str | None = Query(None, description="Match against email, full name, or team name"),
    params: PaginationParams = Depends(),
    service: UserService = Depends(get_user_service),
) -> Page[User]:
    return await service.list_users(params, search=search)


@router.get(
    "/stats/",
    response_model=UserStatsResponse,
    summary="User counters for the dashboard's stat cards (admin)",
    dependencies=[Depends(get_current_superuser)],
)
async def user_stats(service: UserService = Depends(get_user_service)) -> UserStatsResponse:
    return await service.stats()


@router.get("/{user_id}", response_model=UserResponse, summary="Get user by ID (admin)", dependencies=[Depends(get_current_superuser)])
async def get_user(user_id: PydanticObjectId, service: UserService = Depends(get_user_service)) -> User:
    return await service.get_user(user_id)


@router.patch("/{user_id}", response_model=UserResponse, summary="Admin update user", dependencies=[Depends(get_current_superuser)])
async def admin_update_user(
    user_id: PydanticObjectId,
    payload: UserAdminUpdate,
    service: UserService = Depends(get_user_service),
) -> User:
    return await service.admin_update_user(user_id, payload)


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete user (admin)", dependencies=[Depends(get_current_superuser)])
async def delete_user(user_id: PydanticObjectId, service: UserService = Depends(get_user_service)) -> None:
    await service.delete_user(user_id)

"""
Django-compatible UserProfiles router.
Mounted at /api (no /v1 prefix) to match the Flutter frontend's hardcoded URLs:

  GET   /api/UserProfiles/            → list (1-item) of current user's profile
  POST  /api/UserProfiles/            → create / set profile (first-time setup)
  PATCH /api/UserProfiles/{id}/       → update profile (id = user.auto_id)

Flutter UserProfileModel.fromJson() expects:
  id (int), team_logo, team_name, favorite_team, date_of_birth,
  accept_terms_conditions, recived_notifications, created_at, updated_at, user (int)

The `id` field = user.auto_id, used by the waiting room to identify the creator.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from app.modules.auth.dependencies import get_current_user
from app.modules.users.model import User


class ProfileStatsResponse(BaseModel):
    """GET /api/UserProfiles/stats/ — Flutter Profile screen data."""
    team_name: str = ""
    team_logo: str = ""
    since_year: int = 0
    # W / L / NB
    wins: int = 0
    losses: int = 0
    no_match: int = 0          # total_matches - wins - losses
    total_matches: int = 0     # League Play
    # Regular season
    regular_season_wins: int = 0
    league_victories: int = 0  # rank == 1 in completed leagues
    # Trophies (rank-based)
    trophy_gold: int = 0       # 1st place finishes
    trophy_silver: int = 0     # 2nd place finishes
    trophy_bronze: int = 0     # 3rd place finishes
    trophy_other: int = 0      # 4th place (playoff qualifier)
    # Performance
    avg_points_scored: float = 0.0
    avg_points_conceded: float = 0.0

router = APIRouter(prefix="/UserProfiles", tags=["User Profiles (Flutter compat)"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class UserProfileCompatResponse(BaseModel):
    id: int | None = None                # user.auto_id
    team_logo: str = ""
    team_name: str = ""
    favorite_team: str = ""
    date_of_birth: str = ""
    accept_terms_conditions: bool = False
    recived_notifications: bool = False  # typo intentional — matches Flutter
    created_at: str | None = None
    updated_at: str | None = None
    user: int | None = None              # same as id


class UserProfileCreateRequest(BaseModel):
    team_logo: str = ""
    team_name: str = ""
    favorite_team: str = ""
    date_of_birth: str = ""
    accept_terms_conditions: bool = False
    recived_notifications: bool = False


class UserProfileUpdateRequest(BaseModel):
    team_logo: str | None = None
    team_name: str | None = None
    favorite_team: str | None = None
    date_of_birth: str | None = None
    accept_terms_conditions: bool | None = None
    recived_notifications: bool | None = None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _to_profile_response(user: User) -> UserProfileCompatResponse:
    dob = user.date_of_birth.isoformat() if user.date_of_birth else ""
    created = user.created_at.isoformat() if user.created_at else None
    return UserProfileCompatResponse(
        id=user.auto_id,
        team_logo=user.team_logo or "",
        team_name=user.team_name or "",
        favorite_team=user.favourite_team or "",
        date_of_birth=dob,
        accept_terms_conditions=user.terms_accepted,
        recived_notifications=user.push_notifications_enabled,
        created_at=created,
        updated_at=created,
        user=user.auto_id,
    )


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=list[UserProfileCompatResponse],
    summary="Get current user profile (Flutter: fetchUserProfile — returns list)",
)
async def get_user_profiles(
    current_user: User = Depends(get_current_user),
) -> list[UserProfileCompatResponse]:
    if not current_user.is_profile_complete and not current_user.team_name:
        return []
    return [_to_profile_response(current_user)]


@router.post(
    "/",
    response_model=UserProfileCompatResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create / set user profile (Flutter: profile setup first time)",
)
async def create_user_profile(
    payload: UserProfileCreateRequest,
    current_user: User = Depends(get_current_user),
) -> UserProfileCompatResponse:
    from datetime import date as date_type
    dob: date_type | None = None
    if payload.date_of_birth:
        try:
            dob = date_type.fromisoformat(payload.date_of_birth)
        except ValueError:
            pass

    await current_user.save_updated(
        team_logo=payload.team_logo or current_user.team_logo,
        team_name=payload.team_name or current_user.team_name,
        favourite_team=payload.favorite_team or current_user.favourite_team,
        date_of_birth=dob or current_user.date_of_birth,
        terms_accepted=payload.accept_terms_conditions,
        push_notifications_enabled=payload.recived_notifications,
        is_profile_complete=True,
    )
    return _to_profile_response(current_user)


@router.get(
    "/stats/",
    response_model=ProfileStatsResponse,
    summary="Profile statistics overview (Flutter: ProfileScreen — stats, trophies, performance)",
)
async def get_profile_stats(
    current_user: User = Depends(get_current_user),
) -> ProfileStatsResponse:
    from app.modules.leagues.model import League, LeagueMembership, LeagueMatch

    memberships = await LeagueMembership.find(
        LeagueMembership.user_id == current_user.id
    ).to_list()

    if not memberships:
        since_year = current_user.created_at.year if current_user.created_at else datetime.now(timezone.utc).year
        return ProfileStatsResponse(
            team_name=current_user.team_name or "",
            team_logo=current_user.team_logo or "",
            since_year=since_year,
        )

    # ── Aggregate from memberships ─────────────────────────────────────────
    total_wins = sum(m.wins for m in memberships)
    total_losses = sum(m.losses for m in memberships)
    total_pf = sum(m.points_for for m in memberships)
    total_pa = sum(m.points_against for m in memberships)

    # Total completed matches from LeagueMatch
    user_id = current_user.id
    home_matches = await LeagueMatch.find(
        {"home_user_id": user_id, "status": "completed"}
    ).count()
    away_matches = await LeagueMatch.find(
        {"away_user_id": user_id, "status": "completed"}
    ).count()
    total_matches = home_matches + away_matches
    no_match = max(0, total_matches - total_wins - total_losses)

    # ── Performance averages ────────────────────────────────────────────────
    avg_scored = round(total_pf / total_matches, 1) if total_matches else 0.0
    avg_conceded = round(total_pa / total_matches, 1) if total_matches else 0.0

    # ── Trophies (rank-based) ───────────────────────────────────────────────
    trophy_gold   = sum(1 for m in memberships if m.rank == 1)
    trophy_silver = sum(1 for m in memberships if m.rank == 2)
    trophy_bronze = sum(1 for m in memberships if m.rank == 3)
    trophy_other  = sum(1 for m in memberships if m.rank == 4)

    since_year = current_user.created_at.year if current_user.created_at else datetime.now(timezone.utc).year

    return ProfileStatsResponse(
        team_name=current_user.team_name or "",
        team_logo=current_user.team_logo or "",
        since_year=since_year,
        wins=total_wins,
        losses=total_losses,
        no_match=no_match,
        total_matches=total_matches,
        regular_season_wins=total_wins,
        league_victories=trophy_gold,
        trophy_gold=trophy_gold,
        trophy_silver=trophy_silver,
        trophy_bronze=trophy_bronze,
        trophy_other=trophy_other,
        avg_points_scored=avg_scored,
        avg_points_conceded=avg_conceded,
    )


@router.delete(
    "/",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete account (Flutter: ProfileSettings > Delete Account button)",
)
async def delete_account(
    current_user: User = Depends(get_current_user),
) -> None:
    """
    Soft-delete: marks account inactive and anonymises PII.
    Hard-delete of all user data would require cascading deletion of
    LeagueMembership, FlutterPlayerSelection etc. — defer to a background task.
    """
    await current_user.save_updated(
        is_active=False,
        email=f"deleted_{current_user.auto_id}@deleted.invalid",
        team_name=None,
        team_logo=None,
    )


@router.patch(
    "/{profile_id}/",
    response_model=UserProfileCompatResponse,
    summary="Update user profile (Flutter: profile setup update — id = user.auto_id)",
)
async def update_user_profile(
    profile_id: int,
    payload: UserProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
) -> UserProfileCompatResponse:
    from datetime import date as date_type

    updates: dict = {}
    if payload.team_logo is not None:
        updates["team_logo"] = payload.team_logo
    if payload.team_name is not None:
        updates["team_name"] = payload.team_name
    if payload.favorite_team is not None:
        updates["favourite_team"] = payload.favorite_team
    if payload.date_of_birth is not None:
        try:
            updates["date_of_birth"] = date_type.fromisoformat(payload.date_of_birth)
        except ValueError:
            pass
    if payload.accept_terms_conditions is not None:
        updates["terms_accepted"] = payload.accept_terms_conditions
    if payload.recived_notifications is not None:
        updates["push_notifications_enabled"] = payload.recived_notifications

    if updates:
        updates["is_profile_complete"] = True
        await current_user.save_updated(**updates)

    return _to_profile_response(current_user)

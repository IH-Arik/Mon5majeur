from datetime import timedelta

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query

from app.modules.auth.dependencies import get_current_superuser, get_current_user
from app.modules.live_scores.schema import (
    LiveMatchScore,
    PremiumStatusResponse,
)
from app.modules.live_scores.service import LiveScoreService
from app.modules.users.model import User

router = APIRouter(prefix="/live", tags=["Live Scores"])


def get_live_service() -> LiveScoreService:
    return LiveScoreService()


@router.get(
    "/premium-status",
    response_model=PremiumStatusResponse,
    summary="Check if current user has live score access",
)
async def premium_status(
    user: User = Depends(get_current_user),
    service: LiveScoreService = Depends(get_live_service),
) -> PremiumStatusResponse:
    return service.get_premium_status(user)


@router.get(
    "/match/{match_id}",
    response_model=LiveMatchScore,
    summary="Live scores for a duel match (premium only, refresh every 60s)",
)
async def live_match(
    match_id: PydanticObjectId,
    user: User = Depends(get_current_user),
    service: LiveScoreService = Depends(get_live_service),
) -> LiveMatchScore:
    return await service.get_live_match(user, match_id)


# Admin -----------------------------------------------------------------------

@router.post(
    "/admin/grant-premium",
    summary="Admin: grant premium access to a user",
    dependencies=[Depends(get_current_superuser)],
)
async def grant_premium(
    user_id: str = Query(...),
    days: int = Query(30, ge=1),
) -> dict:
    from app.modules.users.model import User as UserModel
    user = await UserModel.get(PydanticObjectId(user_id))
    if not user:
        from app.exceptions.errors import NotFoundException
        raise NotFoundException("User not found")
    svc = LiveScoreService()
    updated = await svc.grant_premium(user, days)
    return {"premium_until": updated.premium_until}

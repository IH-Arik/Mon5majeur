"""
Admin (dashboard) management of the bonus catalog.
Mounted at /api to match the dashboard's hardcoded base URL.

  GET   /api/admin/bonuses/           → list all 5 bonus types with price/status
  PATCH /api/admin/bonuses/{slug}/    → update token_cost and/or is_active

The 5 bonus types are fixed by the Flutter app — this only controls their
price and availability, it cannot create or delete a bonus type.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.exceptions.errors import NotFoundException
from app.modules.auth.dependencies import get_current_superuser
from app.modules.bonuses import catalog

router = APIRouter(
    prefix="/admin/bonuses",
    tags=["Admin: Bonus Catalog"],
    dependencies=[Depends(get_current_superuser)],
)


class BonusOfferResponse(BaseModel):
    slug: str
    display_name: str
    token_cost: int
    is_active: bool


class BonusOfferUpdateRequest(BaseModel):
    token_cost: int | None = Field(default=None, ge=0)
    is_active: bool | None = None


def _to_response(offer) -> BonusOfferResponse:
    return BonusOfferResponse(
        slug=offer.slug,
        display_name=offer.display_name,
        token_cost=offer.token_cost,
        is_active=offer.is_active,
    )


@router.get("/", response_model=list[BonusOfferResponse], summary="List the 5 bonus types")
async def list_bonus_offers() -> list[BonusOfferResponse]:
    offers = await catalog.list_offers()
    return [_to_response(o) for o in offers]


@router.patch(
    "/{slug}/",
    response_model=BonusOfferResponse,
    summary="Update a bonus type's token cost and/or active status",
)
async def update_bonus_offer(slug: str, payload: BonusOfferUpdateRequest) -> BonusOfferResponse:
    offer = await catalog.get_offer(slug)
    if offer is None:
        raise NotFoundException(f"Unknown bonus: {slug}")

    updates = payload.model_dump(exclude_none=True)
    if updates:
        await offer.save_updated(**updates)
    return _to_response(offer)

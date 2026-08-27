"""
Admin (dashboard) management of the token-pack catalog.
Mounted at /api to match the dashboard's hardcoded base URL.

  GET   /api/admin/token-packs/           → list all 4 packs with tokens/price/status
  PATCH /api/admin/token-packs/{slug}/    → update token_amount, price_usd, and/or is_active

The 4 packs are fixed by the Flutter shop screen — this only controls their
token amount, display price, and availability, it cannot create or delete a pack.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.exceptions.errors import NotFoundException
from app.modules.auth.dependencies import get_current_superuser
from app.modules.tokens import catalog
from app.modules.tokens.model import TokenTransaction

router = APIRouter(
    prefix="/admin/token-packs",
    tags=["Admin: Token Pack Catalog"],
    dependencies=[Depends(get_current_superuser)],
)


class TokenPackResponse(BaseModel):
    slug: str
    display_name: str
    token_amount: int
    price_usd: float
    is_active: bool


class TokenPackUpdateRequest(BaseModel):
    token_amount: int | None = Field(default=None, gt=0)
    price_usd: float | None = Field(default=None, ge=0)
    is_active: bool | None = None


class TokenPackStatsResponse(BaseModel):
    total_packs: int
    active_packs: int
    tokens_sold: int
    purchases_count: int


def _to_response(pack) -> TokenPackResponse:
    return TokenPackResponse(
        slug=pack.slug,
        display_name=pack.display_name,
        token_amount=pack.token_amount,
        price_usd=pack.price_usd,
        is_active=pack.is_active,
    )


@router.get("/", response_model=list[TokenPackResponse], summary="List the 4 token packs")
async def list_token_packs() -> list[TokenPackResponse]:
    packs = await catalog.list_packs()
    return [_to_response(p) for p in packs]


@router.get(
    "/stats/",
    response_model=TokenPackStatsResponse,
    summary="Catalog + sales summary for the dashboard's stat cards",
)
async def token_pack_stats() -> TokenPackStatsResponse:
    packs = await catalog.list_packs()

    # "purchase" covers both /mock-purchase and the real IAP webhook — both
    # credit the wallet with that tx_type. Sums the ledger rather than the
    # pack catalog, so it reflects money actually taken in, not price changes
    # made after the fact.
    purchase_txs = await TokenTransaction.find(TokenTransaction.type == "purchase").to_list()

    return TokenPackStatsResponse(
        total_packs=len(packs),
        active_packs=sum(1 for p in packs if p.is_active),
        tokens_sold=sum(tx.amount for tx in purchase_txs),
        purchases_count=len(purchase_txs),
    )


@router.patch(
    "/{slug}/",
    response_model=TokenPackResponse,
    summary="Update a token pack's amount, display price, and/or active status",
)
async def update_token_pack(slug: str, payload: TokenPackUpdateRequest) -> TokenPackResponse:
    pack = await catalog.get_pack(slug)
    if pack is None:
        raise NotFoundException(f"Unknown token pack: {slug}")

    updates = payload.model_dump(exclude_none=True)
    if updates:
        await pack.save_updated(**updates)
    return _to_response(pack)

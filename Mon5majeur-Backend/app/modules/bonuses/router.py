"""
Bonus shop & inventory router.
Mounted at /api (no /v1 prefix) to match Flutter frontend.

  GET  /api/bonuses/my-inventory/    → current user's bonus charges + subscriptions
  POST /api/bonuses/purchase/        → spend tokens, add bonus charge/subscription
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from app.exceptions.errors import BadRequestException
from app.modules.auth.dependencies import get_current_user
from app.modules.bonuses.model import UserBonusInventory
from app.modules.tokens.model import BONUS_COSTS
from app.modules.tokens.service import TokenService
from app.modules.users.model import User

router = APIRouter(prefix="/bonuses", tags=["Bonuses"])

BonusSlug = Literal["chef_curry", "sixth_man", "luxury_tax", "live_scoring", "stop_pub"]

_CHARGE_BONUSES = {"chef_curry", "sixth_man", "luxury_tax"}
_SUBSCRIPTION_BONUSES = {"live_scoring", "stop_pub"}


# ── Schemas ───────────────────────────────────────────────────────────────────

class InventoryResponse(BaseModel):
    sixth_man_charges: int
    chef_curry_charges: int
    luxury_tax_charges: int
    live_scoring_until: datetime | None
    stop_pub_until: datetime | None
    live_scoring_active: bool
    stop_pub_active: bool


class PurchaseRequest(BaseModel):
    bonus: BonusSlug


class PurchaseResponse(BaseModel):
    bonus: str
    token_balance: int
    inventory: InventoryResponse


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_inventory(user: User) -> UserBonusInventory:
    inv = await UserBonusInventory.find_one(UserBonusInventory.user_id == user.id)
    if not inv:
        inv = UserBonusInventory(user_id=user.id)
        await inv.insert()
    return inv


def _aware(dt: datetime | None) -> datetime | None:
    """MongoDB round-trips datetimes as naive UTC — compares against an
    aware `now` below would otherwise raise TypeError."""
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _to_response(inv: UserBonusInventory) -> InventoryResponse:
    now = datetime.now(timezone.utc)
    ls_active = inv.live_scoring_until is not None and _aware(inv.live_scoring_until) > now
    sp_active = inv.stop_pub_until is not None and _aware(inv.stop_pub_until) > now
    return InventoryResponse(
        sixth_man_charges=inv.sixth_man_charges,
        chef_curry_charges=inv.chef_curry_charges,
        luxury_tax_charges=inv.luxury_tax_charges,
        live_scoring_until=inv.live_scoring_until,
        stop_pub_until=inv.stop_pub_until,
        live_scoring_active=ls_active,
        stop_pub_active=sp_active,
    )


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get(
    "/my-inventory/",
    response_model=InventoryResponse,
    summary="Get current user's bonus inventory (Flutter: ShopScreen + BuildTeamTab)",
)
async def my_inventory(
    current_user: User = Depends(get_current_user),
) -> InventoryResponse:
    inv = await _get_inventory(current_user)
    return _to_response(inv)


@router.post(
    "/purchase/",
    response_model=PurchaseResponse,
    status_code=status.HTTP_200_OK,
    summary="Purchase a bonus from the shop (deducts tokens, adds to inventory)",
)
async def purchase_bonus(
    payload: PurchaseRequest,
    current_user: User = Depends(get_current_user),
) -> PurchaseResponse:
    cost = BONUS_COSTS.get(payload.bonus)
    if cost is None:
        raise BadRequestException(f"Unknown bonus: {payload.bonus}")

    svc = TokenService()

    # Deduct tokens from wallet (raises BadRequestException if insufficient)
    wallet = await svc.debit(
        current_user.id,
        cost,
        tx_type="bonus_activation",
        reference_id=payload.bonus,
        note=f"Shop purchase: {payload.bonus}",
    )

    # Update inventory
    inv = await _get_inventory(current_user)
    now = datetime.now(timezone.utc)

    if payload.bonus in _CHARGE_BONUSES:
        field = f"{payload.bonus}_charges"
        setattr(inv, field, getattr(inv, field) + 1)
    elif payload.bonus == "live_scoring":
        current_expiry = inv.live_scoring_until
        base = current_expiry if current_expiry and current_expiry > now else now
        inv.live_scoring_until = base + timedelta(days=365)
        # This is what live_scores/service.py._is_premium actually checks —
        # without syncing it here, a purchase would update the inventory but
        # never actually unlock the live-score endpoint (403 forever).
        current_user.premium_until = inv.live_scoring_until
        await current_user.save()
    elif payload.bonus == "stop_pub":
        current_expiry = inv.stop_pub_until
        base = current_expiry if current_expiry and current_expiry > now else now
        inv.stop_pub_until = base + timedelta(days=365)

    await inv.save()

    return PurchaseResponse(
        bonus=payload.bonus,
        token_balance=wallet.balance,
        inventory=_to_response(inv),
    )

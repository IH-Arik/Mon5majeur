from datetime import datetime

from beanie import PydanticObjectId
from pydantic import Field

from app.shared.base_schema import BaseSchema


class WalletResponse(BaseSchema):
    user_id: PydanticObjectId
    balance: int


class TransactionResponse(BaseSchema):
    id: PydanticObjectId
    amount: int
    balance_after: int
    type: str
    reference_id: str | None
    note: str | None
    created_at: datetime


class IAPWebhookPayload(BaseSchema):
    """Payload from the in-app purchase webhook (App Store / Play Store)."""
    user_id: str
    product_id: str
    transaction_id: str
    tokens_to_credit: int = Field(..., gt=0)
    platform: str = Field(..., description="ios | android")


class AdminGrantRequest(BaseSchema):
    user_id: str
    tokens: int = Field(..., gt=0)
    note: str | None = None


class MockPurchaseRequest(BaseSchema):
    """TEMPORARY (see router.py) — real-money token packs, no store account
    wired up yet. `pack` selects a fixed server-side token amount; the
    client never dictates how many tokens it gets."""
    pack: str

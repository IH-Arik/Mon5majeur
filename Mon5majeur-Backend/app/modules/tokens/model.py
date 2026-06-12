from datetime import datetime
from typing import Literal

from beanie import PydanticObjectId
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.database.base import BaseDocument


class TokenWallet(BaseDocument):
    """One wallet per user. Balance in tokens (integers)."""
    user_id: PydanticObjectId
    balance: int = 0

    class Settings:
        name = "token_wallets"
        indexes = [
            IndexModel([("user_id", ASCENDING)], unique=True),
        ]


class TokenTransaction(BaseDocument):
    """
    Immutable ledger entry. One row per credit/debit event.
    Never modify — only insert.
    """
    user_id: PydanticObjectId
    amount: int                  # positive = credit, negative = debit
    balance_after: int
    type: Literal[
        "purchase",              # IAP webhook
        "bonus_activation",      # spent to activate a bonus
        "refund",                # admin refund
        "admin_grant",           # admin manually credited
    ]
    reference_id: str | None = None   # e.g. store transaction ID, bonus slug
    note: str | None = None

    class Settings:
        name = "token_transactions"
        indexes = [
            IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)]),
            IndexModel([("type", ASCENDING)]),
        ]


# Token costs for bonus activations (in tokens)
BONUS_COSTS = {
    "luxury_tax": 50,
    "chef_curry": 50,
    "sixth_man": 50,
}

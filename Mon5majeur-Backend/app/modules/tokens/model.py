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
        "earn_daily_video",      # rewarded ad watch (daily limit)
        "earn_match_win",        # earned by winning a league match
        "earn_league_win",       # earned by winning a full league
    ]
    reference_id: str | None = None   # e.g. store transaction ID, bonus slug
    note: str | None = None

    class Settings:
        name = "token_transactions"
        indexes = [
            IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)]),
            IndexModel([("type", ASCENDING)]),
        ]


# Shop purchase costs per bonus (spec prices, in tokens)
BONUS_COSTS = {
    "chef_curry": 130,
    "sixth_man": 170,
    "luxury_tax": 150,
    "live_scoring": 450,   # per-year subscription
    "stop_pub": 450,       # per-year subscription
}

DAILY_VIDEO_REWARD = 6   # tokens earned per rewarded-ad video

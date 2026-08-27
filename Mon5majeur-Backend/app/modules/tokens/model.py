from datetime import datetime
from typing import Literal

from beanie import PydanticObjectId
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.database.base import BaseDocument

TokenPackSlug = Literal["rookie", "all_star", "mvp", "hall_of_fame"]


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


DAILY_VIDEO_REWARD = 6   # tokens earned per rewarded-ad video


class TokenPack(BaseDocument):
    """
    Admin-editable catalog row for one of the 4 fixed token packs shown in
    the Flutter shop (buy_token.dart hardcodes these 4 slugs and their icons)
    — there is no "create a new pack" here, only price/availability control
    over the existing 4. See tokens.catalog for seeding and defaults.

    price_usd is informational only (shown in the dashboard) — /mock-purchase
    doesn't charge real money, and once real IAP is wired up, the actual
    charge is whatever price is configured in the App Store / Play Store
    product, not this field.
    """
    slug: TokenPackSlug
    display_name: str
    token_amount: int
    price_usd: float
    is_active: bool = True

    class Settings:
        name = "token_packs"
        indexes = [
            IndexModel([("slug", ASCENDING)], unique=True),
        ]

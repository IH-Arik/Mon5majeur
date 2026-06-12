from datetime import date

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class UserBonusQuota(BaseDocument):
    """
    Tracks per-user per-league bonus usage.
    Each bonus can only be used once per season per league.
    """
    user_id: PydanticObjectId
    league_id: PydanticObjectId

    # One-use bonuses per season
    luxury_tax_used: bool = False          # +5M budget before lock
    luxury_tax_used_date: date | None = None

    chef_curry_used: bool = False          # +3pts after scoring
    chef_curry_used_date: date | None = None

    sixth_man_used: bool = False           # best 5 of 6 players
    sixth_man_used_date: date | None = None

    class Settings:
        name = "user_bonus_quotas"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("league_id", ASCENDING)],
                unique=True,
            ),
        ]

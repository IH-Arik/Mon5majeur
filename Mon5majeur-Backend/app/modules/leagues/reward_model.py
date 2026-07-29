from datetime import date

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class GlobalLeagueReward(BaseDocument):
    """
    Record of a Global League Weekly Top-8 / Monthly Winner reward grant.
    Exists purely for idempotency (never double-grant the same period) and
    as an audit trail — physical rewards (the monthly jersey) still need
    manual fulfillment by the team.
    """
    user_id: PydanticObjectId
    period_type: str        # "weekly" | "monthly"
    period_key: str         # e.g. "2026-W05" or "2026-07"
    rank: int
    granted_at: date

    class Settings:
        name = "global_league_rewards"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("period_type", ASCENDING), ("period_key", ASCENDING)],
                unique=True,
            ),
        ]

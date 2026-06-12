from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class FantasyTeam(BaseDocument):
    owner_id: PydanticObjectId
    name: str
    competition_id: PydanticObjectId | None = None  # None = personal team (no contest)

    # Exactly 5 player IDs — positions: PG, SG, SF, PF, C
    player_ids: list[PydanticObjectId]              # ordered by REQUIRED_POSITIONS

    total_fantasy_score: float = 0.0
    is_submitted: bool = False                       # locked after submission to contest

    class Settings:
        name = "fantasy_teams"
        indexes = [
            IndexModel([("owner_id", ASCENDING)]),
            IndexModel([("competition_id", ASCENDING)]),
            IndexModel([("total_fantasy_score", ASCENDING)]),
        ]

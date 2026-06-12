from datetime import datetime

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class FlutterPlayerSelection(BaseDocument):
    """Stores the player selection a user submitted for a league match day."""
    user_id: PydanticObjectId
    league_id: PydanticObjectId
    league_auto_id: int
    match_day: int
    selected_players: list[dict] = []   # raw Flutter Player.toApiJson() payloads
    submitted_at: datetime

    class Settings:
        name = "flutter_player_selections"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("league_auto_id", ASCENDING), ("match_day", ASCENDING)],
                unique=True,
            ),
            IndexModel([("league_auto_id", ASCENDING), ("match_day", ASCENDING)]),
        ]

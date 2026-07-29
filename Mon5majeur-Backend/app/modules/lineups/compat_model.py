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

    # Strategic bonuses (spec §4.4) — duel leagues only, never set for the
    # Global League (no bonuses there). luxury_tax affects the budget check
    # at save time; chef_curry/sixth_man_player affect scoring at duel time.
    luxury_tax: bool = False
    chef_curry: bool = False
    sixth_man_player: dict | None = None   # raw Player.toApiJson(), price ≤ 8M

    class Settings:
        name = "flutter_player_selections"
        indexes = [
            IndexModel(
                [("user_id", ASCENDING), ("league_auto_id", ASCENDING), ("match_day", ASCENDING)],
                unique=True,
            ),
            IndexModel([("league_auto_id", ASCENDING), ("match_day", ASCENDING)]),
        ]

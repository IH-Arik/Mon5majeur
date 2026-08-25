from datetime import date, datetime

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

    # The NBA match night (US/EST Goalserve date) this lineup was played for.
    # `match_day` is only a per-league counter, so it cannot be compared
    # across leagues or turned into a calendar date on its own — retention
    # analytics needs a real night, and deriving one at query time would be
    # both slow and ambiguous. Stamped at submit time.
    # None on rows written before this field existed; those are filled in by
    # scripts/backfill_lineup_nba_date.py.
    nba_date: date | None = None

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
            # Retention dashboard reads every metric by night, and block 5
            # additionally narrows by league.
            IndexModel([("nba_date", ASCENDING)]),
            IndexModel([("nba_date", ASCENDING), ("league_id", ASCENDING)]),
        ]

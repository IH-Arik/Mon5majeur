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

    # Substitute (lineup rule, NOT a bonus): outside the 100M budget, comes in
    # for one starter of 10M+ who played 0 minute (leagues/substitution.py).
    # None = no substitute: every lineup saved before this field existed, which
    # therefore keeps exactly the score it had. `price` inside the dict is the
    # reference price read from the database when the lineup was validated.
    substitute_player: dict | None = None
    substitute_set_at: datetime | None = None

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
            # cohort_retention() groups by (user, night); users/service stats
            # filter by submitted_at (audit 1.4).
            IndexModel([("user_id", ASCENDING), ("nba_date", ASCENDING)]),
            IndexModel([("submitted_at", ASCENDING)]),
        ]

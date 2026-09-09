"""
Picks the one duel a push should talk about (spec §4.8).

Two rules drive both the 19:00 reminder and the 09:00 results push:

  * one push per user per moment — never a burst, even when the user plays
    several leagues that night;
  * when several leagues qualify, the private one wins, because that is the
    duel against people the user actually knows.

The golden rule ("never spoil") lives at the call sites: this module only
supplies the opponent's name and which flavour of league it was. It never
returns a score.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from beanie import PydanticObjectId

from app.modules.leagues.constants import (
    LEAGUE_STATUS_PLAYOFFS,
    LEAGUE_STATUS_REGULAR,
    LEAGUE_TYPE_PRIVATE,
    LEAGUE_TYPE_PUBLIC,
)
from app.modules.leagues.model import League, LeagueMatch
from app.modules.users.model import User

_ACTIVE_STATUSES = (LEAGUE_STATUS_REGULAR, LEAGUE_STATUS_PLAYOFFS)
# Private first: ordering is the priority rule, not a cosmetic detail.
_DUEL_TYPES = (LEAGUE_TYPE_PRIVATE, LEAGUE_TYPE_PUBLIC)


@dataclass(frozen=True)
class DuelContext:
    """The duel a notification should mention, for one user on one night."""

    user_id: PydanticObjectId
    league: League
    match: LeagueMatch
    opponent_name: str

    @property
    def is_private(self) -> bool:
        return self.league.type == LEAGUE_TYPE_PRIVATE


def _display_name(user: User | None) -> str:
    if user is None:
        return "your opponent"
    return (user.team_name or user.full_name or "your opponent").strip() or "your opponent"


async def duel_contexts_for_night(night: date) -> dict[PydanticObjectId, DuelContext]:
    """One DuelContext per user with a duel on `night`, private preferred.

    Returns a dict keyed by user so callers get the de-duplication for free:
    iterating it can only ever produce one push per user.
    """
    leagues = await League.find(
        {
            "type": {"$in": list(_DUEL_TYPES)},
            "status": {"$in": list(_ACTIVE_STATUSES)},
        }
    ).to_list()
    if not leagues:
        return {}

    league_by_id = {lg.id: lg for lg in leagues}

    matches = await LeagueMatch.find(
        {
            "league_id": {"$in": list(league_by_id)},
            "nba_date": night,
        }
    ).to_list()
    if not matches:
        return {}

    # Resolve every participant in one query rather than per match.
    user_ids = {uid for m in matches for uid in (m.home_user_id, m.away_user_id)}
    users = await User.find({"_id": {"$in": list(user_ids)}}).to_list()
    user_by_id = {u.id: u for u in users}

    chosen: dict[PydanticObjectId, DuelContext] = {}

    for match in matches:
        league = league_by_id.get(match.league_id)
        if league is None:
            continue

        for user_id, opponent_id in (
            (match.home_user_id, match.away_user_id),
            (match.away_user_id, match.home_user_id),
        ):
            existing = chosen.get(user_id)
            # Keep the first duel found, unless this one is private and the
            # one already held is not.
            if existing is not None and not (
                league.type == LEAGUE_TYPE_PRIVATE and not existing.is_private
            ):
                continue

            chosen[user_id] = DuelContext(
                user_id=user_id,
                league=league,
                match=match,
                opponent_name=_display_name(user_by_id.get(opponent_id)),
            )

    return chosen

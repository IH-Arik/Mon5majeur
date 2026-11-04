"""
Saving the substitute with a lineup (duels and Global League).

The substitute is optional and outside the 100M budget. His price is read from
the database when the lineup is validated, never taken from the request, and
must be 10M or less. He gets the same checks as a starter (plays tonight, not
OUT) and cannot be a starter or the 6th Man.

Three cases for the request field ``substitute_player``:
  * sent as a player  -> validated and stored;
  * sent as null      -> the substitute is removed;
  * absent (an older app, which does not know the field) -> the existing
    substitute is kept; if the new lineup made him a starter or the 6th Man he
    is dropped instead of refusing the save.

Locking is not handled here: the callers already refuse any save of a locked
lineup (``ensure_open``) before reaching this point, so the substitute cannot be
added, changed or removed after the lock either.
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import ForbiddenException
from app.modules.leagues.substitution import SUBSTITUTE_MAX_PRICE


def _id(player: dict | None) -> str:
    return str(player.get("id", "")) if player else ""


def _fmt(price: float) -> str:
    return f"{price:g}M"


async def prepare_substitute(
    *,
    provided: bool,
    requested: dict | None,
    existing: dict | None,
    existing_set_at: datetime | None,
    starters: list[dict],
    sixth_man: dict | None,
    nba_date: date | None,
) -> tuple[dict | None, datetime | None]:
    """Returns (substitute to store, substitute_set_at). Raises ForbiddenException
    with an English message (the app translates the fixed texts)."""
    starter_ids = {_id(p) for p in starters}
    sixth_id = _id(sixth_man)

    if not provided:
        # Older app: keep what is there, unless the new lineup took him.
        if existing is None or _id(existing) in starter_ids or (sixth_id and _id(existing) == sixth_id):
            return None, None
        return existing, existing_set_at

    if requested is None:
        return None, None

    rid = _id(requested)
    if not rid:
        raise ForbiddenException("The substitute must have an id")
    if rid in starter_ids:
        raise ForbiddenException("The substitute cannot also be a starter")
    if sixth_id and rid == sixth_id:
        raise ForbiddenException("The substitute cannot also be the 6th Man")

    from app.modules.players.model import NBAGame, Player

    try:
        player = await Player.get(PydanticObjectId(rid))
    except Exception:
        player = None
    if not player:
        raise ForbiddenException(f"Player {rid} not found")

    # Same two checks as the starters (and skipped in the same case: no night to
    # check against).
    if nba_date is not None:
        from app.modules.players.teams_playing import TeamsPlaying

        games = await NBAGame.find(NBAGame.nba_date == nba_date).to_list()
        if not TeamsPlaying(games).plays(player.team_name, player.team_goalserve_id):
            raise ForbiddenException(f"{player.full_name} does not play tonight")
        if player.is_out:
            raise ForbiddenException(f"{player.full_name} is OUT and cannot be selected")

    price = float(player.daily_price)
    if price > SUBSTITUTE_MAX_PRICE:
        raise ForbiddenException(
            f"The substitute costs {_fmt(price)} — must be {_fmt(SUBSTITUTE_MAX_PRICE)} or less"
        )

    stored = dict(requested)
    stored["id"] = str(player.id)
    stored["price"] = _fmt(price)          # the database's price, whatever the app sent
    return stored, datetime.now(timezone.utc)

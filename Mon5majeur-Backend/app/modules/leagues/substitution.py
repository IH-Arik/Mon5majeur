"""
Substitute rule ("remplaçant") — one pure function shared by every score path.

A lineup is 5 starters + an optional substitute, outside the 100M budget. The
substitute (<= 10M at validation, see ``SUBSTITUTE_MAX_PRICE``) comes in for ONE
starter who cost 10M or more and played 0 minutes:

  * several eligible starters  -> the most expensive one is replaced; on a
    price tie the lowest player id wins, so every screen shows the same
    replacement and the total does not depend on the list order;
  * the substitute himself played 0 minutes -> he still comes in (0 point);
  * nobody eligible -> he does not come in and counts for nothing;
  * a lineup without a substitute (every lineup saved before this rule) is
    returned untouched.

The substitute never inherits a bonus from the starter he replaces: the bonuses
(Chef Curry +3, 6th Man, Luxury Tax) belong to the lineup, not to a player, so
this function leaves them to each score path.

The function only decides WHO counts. Each caller keeps its own scoring rule and
simply scores ``result.starters`` instead of the five saved starters; the
replaced starter is not in that list (he counts for nothing, shown as absent).

Prices are the ones stored in the lineup at validation, never today's price.
``minutes_by_player`` maps player id -> minutes played; a missing id counts as 0
minute (a game that is not final when the night is closed, e.g. postponed, gives
no minutes). While the games are still being played the caller passes
``settled=False``: nothing is decided yet, so nothing is shown (live).
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Sequence

SUBSTITUTE_MAX_PRICE = 10.0       # M, checked when the lineup is validated
REPLACEABLE_MIN_PRICE = 10.0      # M, a starter must cost at least this much

NONE = "none"                     # no substitute in this lineup
PENDING = "pending"               # games not all final: nothing decided yet
NOT_ENTERED = "not_entered"       # nobody eligible was absent
ENTERED = "entered"


@dataclass(frozen=True)
class SubstitutionResult:
    status: str
    starters: list[dict]          # the five that count (substitute in place of the replaced one)
    substitute: dict | None = None
    replaced: dict | None = None

    @property
    def entered(self) -> bool:
        return self.status == ENTERED


def _id(player: dict) -> str:
    return str(player.get("id", ""))


def _price(player: dict) -> float:
    try:
        return float(str(player.get("price", "0")).replace("M", "").strip())
    except (ValueError, TypeError):
        return 0.0


def apply_substitution(
    starters: Sequence[dict],
    substitute: dict | None,
    minutes_by_player: Mapping[str, int | None],
    *,
    settled: bool = True,
) -> SubstitutionResult:
    starters = list(starters)
    if substitute is None:
        return SubstitutionResult(NONE, starters)

    # Validation refuses a substitute who is also a starter; if one slips
    # through, never count the same player twice.
    sub_id = _id(substitute)
    if not sub_id or sub_id in {_id(p) for p in starters}:
        return SubstitutionResult(NONE, starters)

    if not settled:
        return SubstitutionResult(PENDING, starters, substitute)

    eligible = [
        p for p in starters
        if _price(p) >= REPLACEABLE_MIN_PRICE and not (minutes_by_player.get(_id(p)) or 0) > 0
    ]
    if not eligible:
        return SubstitutionResult(NOT_ENTERED, starters, substitute)

    replaced = min(eligible, key=lambda p: (-_price(p), _id(p)))
    counted = [substitute if p is replaced else p for p in starters]
    return SubstitutionResult(ENTERED, counted, substitute, replaced)

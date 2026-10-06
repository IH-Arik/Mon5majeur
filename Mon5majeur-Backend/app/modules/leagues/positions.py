"""Lineup position rule: 2 backcourt + 2 wings + 1 center.

Players often carry several positions (G, F, G-F, F-G, F-C, C-F ...), so a
label can fit more than one slot. The rule is met as soon as ONE assignment of
the five players to the five slots exists - not by counting each label once in
the order players were added (QA #9 6.1: valid lineups were refused).
"""
from __future__ import annotations

import re
from itertools import permutations

BACKCOURT, WING, CENTER = "B", "W", "C"

# Slots of a lineup, in order: two backcourt, two wings, one center.
SLOTS = (BACKCOURT, BACKCOURT, WING, WING, CENTER)

_TOKEN_SLOT = {
    "PG": BACKCOURT, "SG": BACKCOURT, "G": BACKCOURT,
    "SF": WING, "PF": WING, "F": WING,
    "C": CENTER,
}


def slots_for(label: str | None) -> set[str]:
    """Slot kinds a position label can fill; empty for an unknown label."""
    kinds: set[str] = set()
    for token in re.split(r"[-/ ,]+", (label or "").upper().strip()):
        kind = _TOKEN_SLOT.get(token)
        if kind:
            kinds.add(kind)
    return kinds


def can_fill_lineup(labels: list[str | None]) -> bool:
    """True if the five players can be placed on 2 backcourt + 2 wing + 1
    center slots, each in a slot its label allows."""
    if len(labels) != len(SLOTS):
        return False
    allowed = [slots_for(label) for label in labels]
    # 5! = 120 assignments: trivial, and exact (no greedy ordering effects).
    return any(
        all(slot in allowed[i] for i, slot in enumerate(perm))
        for perm in permutations(SLOTS)
    )


# Order the court draws the five starters in: left wing, center, right wing,
# left guard, right guard (the Global League layout).
COURT_ORDER = (WING, CENTER, WING, BACKCOURT, BACKCOURT)


def court_order(labels: list[str | None]) -> list[int] | None:
    """Indexes of `labels` arranged in COURT_ORDER (wing, center, wing, guard,
    guard), or None when no valid assignment exists. Lets a lineup be drawn by
    position instead of by the order players were added."""
    if len(labels) != len(COURT_ORDER):
        return None
    allowed = [slots_for(label) for label in labels]
    for perm in permutations(range(len(labels))):
        if all(COURT_ORDER[slot] in allowed[i] for slot, i in enumerate(perm)):
            return list(perm)
    return None

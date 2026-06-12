REQUIRED_SLOTS = ("PG", "SG", "SF", "PF", "C")

# Slot count when 6th Man bonus is active
SIXTH_MAN_SLOT_COUNT = 6
SIXTH_MAN_SLOT_NAME = "SIXTH_MAN"
SIXTH_MAN_MAX_PRICE = 8  # millions — strict upper bound per spec

# Base budget (millions). Luxury Tax bonus adds 5M before lock.
BASE_BUDGET = 100
LUXURY_TAX_EXTRA = 5

# Minimum price any player can have (enforced server-side)
MIN_PLAYER_PRICE = 3.0

# Position families per slot (spec §4.1)
# Backcourt slots accept PG, SG, or G (generic guard)
# Wing slots accept SF, PF, or F (generic forward)
# Center slot accepts C only
# SIXTH_MAN accepts any position
SLOT_ALLOWED_POSITIONS: dict[str, tuple[str, ...]] = {
    "PG":         ("PG", "SG", "G"),
    "SG":         ("PG", "SG", "G"),
    "SF":         ("SF", "PF", "F"),
    "PF":         ("SF", "PF", "F"),
    "C":          ("C",),
    "SIXTH_MAN":  ("PG", "SG", "SF", "PF", "C", "G", "F"),
}

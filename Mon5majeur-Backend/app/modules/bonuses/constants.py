"""Free bonus quota per duel league, sized by league size (spec §4.4)."""

FREE_QUOTA_BY_SIZE: dict[int, dict[str, int]] = {
    4:  {"chef_curry": 1, "luxury_tax": 1, "sixth_man": 1},
    6:  {"chef_curry": 2, "luxury_tax": 1, "sixth_man": 2},
    8:  {"chef_curry": 2, "luxury_tax": 2, "sixth_man": 2},
    10: {"chef_curry": 3, "luxury_tax": 3, "sixth_man": 3},
}

# Fallback for any non-standard size — clamp to the nearest defined bracket
# rather than silently granting zero (fail open toward the smallest quota).
_DEFAULT_QUOTA = FREE_QUOTA_BY_SIZE[4]


def free_quota_for(max_size: int, bonus: str) -> int:
    return FREE_QUOTA_BY_SIZE.get(max_size, _DEFAULT_QUOTA).get(bonus, 0)

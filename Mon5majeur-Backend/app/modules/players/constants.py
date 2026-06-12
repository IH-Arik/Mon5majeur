GOALSERVE_BASE_URL = "https://www.goalserve.com/getfeed"

SPORT = "basketball"
CATEGORY_NBA = "nba"
CATEGORY_EUROLEAGUE = "euroleague"

POSITIONS = ("PG", "SG", "SF", "PF", "C")
POSITION_LABELS = {
    "PG": "Point Guard",
    "SG": "Shooting Guard",
    "SF": "Small Forward",
    "PF": "Power Forward",
    "C": "Center",
}

# Goalserve XML field names for box-score stats
# These are the attribute names on the <player> element inside a game box-score.
# IMPORTANT: `two_pt` is an American football field — NEVER use it for basketball.
GOALSERVE_STAT_FIELDS = {
    "pts": "points",
    "reb": "rebounds",
    "ast": "assists",
    "stl": "steals",
    "blk": "blocks",
    "tov": "turnovers",
    "fgm": "field_goals_made",
    "fga": "field_goals_attempted",
    "tpm": "threepoint_made",
    "tpa": "threepoint_attempted",
    "ftm": "freethrow_made",
    "fta": "freethrow_attempted",
    "min": "minutes_played",
}

# Injury / availability keywords that mean "will not play"
OUT_KEYWORDS = frozenset({
    "out", "sidelined", "will not play", "dnp", "did not play",
    "inactive", "doubtful", "injured",
})

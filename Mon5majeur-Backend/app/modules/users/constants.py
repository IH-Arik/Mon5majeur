USER_NOT_FOUND = "User not found"
EMAIL_ALREADY_EXISTS = "Email already registered"
CANNOT_DELETE_SELF = "You cannot delete your own account"

# Predefined team logos available for selection
TEAM_LOGOS = [
    {"slug": "devil",     "label": "Devil"},
    {"slug": "flower",    "label": "Flower"},
    {"slug": "ufo",       "label": "UFO"},
    {"slug": "shark",     "label": "Shark"},
    {"slug": "lightning", "label": "Lightning"},
    {"slug": "dragon",    "label": "Dragon"},
]

TEAM_LOGO_SLUGS = {logo["slug"] for logo in TEAM_LOGOS}

# NBA teams (30 franchises)
NBA_TEAMS = [
    "Atlanta Hawks",
    "Boston Celtics",
    "Brooklyn Nets",
    "Charlotte Hornets",
    "Chicago Bulls",
    "Cleveland Cavaliers",
    "Dallas Mavericks",
    "Denver Nuggets",
    "Detroit Pistons",
    "Golden State Warriors",
    "Houston Rockets",
    "Indiana Pacers",
    "LA Clippers",
    "Los Angeles Lakers",
    "Memphis Grizzlies",
    "Miami Heat",
    "Milwaukee Bucks",
    "Minnesota Timberwolves",
    "New Orleans Pelicans",
    "New York Knicks",
    "Oklahoma City Thunder",
    "Orlando Magic",
    "Philadelphia 76ers",
    "Phoenix Suns",
    "Portland Trail Blazers",
    "Sacramento Kings",
    "San Antonio Spurs",
    "Toronto Raptors",
    "Utah Jazz",
    "Washington Wizards",
]

# Notification type identifiers (maps to push notification categories)
NOTIFICATION_TYPES = [
    {"slug": "team_reminder", "label": "Don't forget to make your team"},
    {"slug": "results",       "label": "The results are in"},
]

NOTIFICATION_TYPE_SLUGS = {n["slug"] for n in NOTIFICATION_TYPES}

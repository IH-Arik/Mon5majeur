from datetime import date, datetime
from typing import Annotated, Literal

from beanie import PydanticObjectId
from pydantic import StringConstraints, computed_field, field_validator

from app.modules.leagues.constants import (
    BUDGET_PREMIUM,
    BUDGET_STANDARD,
    VALID_LEAGUE_SIZES,
)
from app.shared.base_schema import BaseSchema


# ── Create / Join ─────────────────────────────────────────────────────────────

class CreateLeagueRequest(BaseSchema):
    name: Annotated[str, StringConstraints(min_length=2, max_length=50)]
    type: Literal["private", "public"]
    budget: int = BUDGET_PREMIUM
    max_size: int = 10

    @field_validator("budget")
    @classmethod
    def validate_budget(cls, v: int) -> int:
        if v not in (BUDGET_STANDARD, BUDGET_PREMIUM):
            raise ValueError(f"Budget must be {BUDGET_STANDARD} or {BUDGET_PREMIUM}")
        return v

    @field_validator("max_size")
    @classmethod
    def validate_size(cls, v: int) -> int:
        if v not in VALID_LEAGUE_SIZES:
            raise ValueError(f"League size must be one of {VALID_LEAGUE_SIZES}")
        return v


class JoinLeagueRequest(BaseSchema):
    # Frontend sends 'join_code'; accept both for flexibility
    join_code: str | None = None
    invite_code: str | None = None

    @property
    def code(self) -> str:
        """Return whichever field was provided."""
        return (self.join_code or self.invite_code or "").strip().upper()


# ── Responses ─────────────────────────────────────────────────────────────────

class LeagueResponse(BaseSchema):
    id: PydanticObjectId
    name: str
    type: str
    status: str
    budget: int
    max_size: int
    current_size: int
    invite_code: str | None = None
    current_match_day: int
    current_week: int
    total_match_days: int
    started_at: datetime | None
    created_at: datetime

    @computed_field  # type: ignore[prop-decorator]
    @property
    def league_id(self) -> str:
        """Alias for `id` as a string — consumed by the Flutter frontend."""
        return str(self.id)


class MyLeagueResponse(BaseSchema):
    """League card as shown in My Leagues screen."""
    id: PydanticObjectId
    name: str
    type: str
    status: str
    budget: int
    max_size: int
    current_size: int
    current_match_day: int
    current_week: int
    total_match_days: int
    # user's standing in this league
    rank: int | None
    wins: int
    losses: int
    points_for: float
    points_against: float


class MatchPlayerInfo(BaseSchema):
    """Minimal info for one side of a duel card."""
    user_id: PydanticObjectId
    team_name: str | None
    team_logo: str | None


class LeagueMatchResponse(BaseSchema):
    """Match card as shown in My Matches Today screen."""
    id: PydanticObjectId
    league_id: PydanticObjectId
    league_name: str
    match_day: int
    nba_date: date
    status: str
    home: MatchPlayerInfo
    away: MatchPlayerInfo
    home_score: float | None
    away_score: float | None


class GlobalLeagueStatusResponse(BaseSchema):
    joined: bool
    league_id: PydanticObjectId | None = None
    status: str | None = None
    current_week: int = 0
    current_match_day: int = 0


class PublicLeagueListItem(BaseSchema):
    """Compact card shown in the Public League list on the Choose a League screen."""
    id: PydanticObjectId
    name: str
    current_size: int
    max_size: int
    budget: int
    status: str


class JoinScreenResponse(BaseSchema):
    """Single call to populate the entire 'Choose a league' screen."""
    public_leagues_preview: list[PublicLeagueListItem]   # first 4 for preview
    public_leagues_total: int                             # for "Explore all leagues" count


# ── Waiting Room / Detail ─────────────────────────────────────────────────────

class TeamInfoResponse(BaseSchema):
    """One member in the waiting room team list — matches Flutter TeamInfo.fromJson (int team_id)."""
    team_id: int | None = None   # user auto_id integer (Flutter declares int)
    team_name: str | None = None
    team_logo: str | None = None


# ── Django-compat (Flutter calls /api/public-leagues/...) ────────────────────

class CreatePublicLeagueRequest(BaseSchema):
    """Body Flutter sends to POST /api/public-leagues/ — uses the typo field names."""
    leauge_name: str
    leauge_logo: str = ""
    leauge_description: str = ""
    team_budget: str = "100M"    # "80M" or "100M"
    max_team_number: str = "10"  # "4","6","8","10"

    @property
    def budget_int(self) -> int:
        try:
            return int(self.team_budget.replace("M", "").strip())
        except (ValueError, AttributeError):
            return 100

    @property
    def max_size_int(self) -> int:
        try:
            return int(self.max_team_number.strip())
        except (ValueError, AttributeError):
            return 10


class JoinPublicLeagueByIdRequest(BaseSchema):
    """Body Flutter sends to POST /api/public-leagues/join/."""
    league_id: int


class PublicLeagueCompatResponse(BaseSchema):
    """
    Matches Flutter PrivateLeagueModel.fromJson() exactly.
    `id` is the auto_id integer — Flutter declares it as `int?`.
    """
    model_config = {"populate_by_name": True}

    id: int | None = None               # auto_id (integer) for Flutter
    leauge_name: str = ""
    leauge_description: str = ""
    leauge_logo: str = ""
    team_budget: str = "100M"
    max_team_number: str = "10"
    join_code: str | None = None
    creator: int | None = None       # admin user's auto_id — Flutter compares against userProfile.id
    current_match_day: int = 0
    is_ready: bool = False
    is_started: bool = False
    is_active: bool = True
    created_at: datetime
    start_date: datetime | None = None
    teams: list[TeamInfoResponse] = []

    # My Leagues launch spec: per-user lineup validation for *today* (not the
    # league in general). Only populated by get_my_leagues_compat(); every
    # other builder of this response (create/join/detail) leaves the defaults
    # since "today's lineup" isn't meaningful outside the My Leagues list.
    lineup_submitted: bool = False
    lock_in_seconds: int | None = None


class LeagueDetailResponse(BaseSchema):
    """
    Detailed league response consumed by the Flutter waiting-room screens.
    Field aliases match PrivateLeagueModel.fromJson() — including the 'leauge' typos.
    """
    model_config = {"populate_by_name": True}

    id: str                             # league MongoDB id as string

    # Flutter reads: json['leauge_name']  (note: typo in frontend)
    leauge_name: str = ""
    leauge_description: str = ""
    leauge_logo: str = ""

    # Flutter reads: json['team_budget'], json['max_team_number']
    team_budget: str = "100M"
    max_team_number: str = "10"

    # Flutter reads: json['join_code']
    join_code: str | None = None

    # Flutter reads: json['creator']  (team/user id as string)
    creator: str | None = None

    current_match_day: int = 0
    is_ready: bool = False
    is_started: bool = False
    is_active: bool = True

    created_at: datetime
    start_date: datetime | None = None

    teams: list[TeamInfoResponse] = []


# ── Django-compat: Private Leagues ────────────────────────────────────────────

class UpdateLeagueCompatRequest(BaseSchema):
    """Body for PATCH /api/private-leagues/{id}/ and PUT /api/public-leagues/{id}/."""
    leauge_name: str
    leauge_logo: str = ""
    leauge_description: str = ""
    team_budget: str = "100M"
    max_team_number: str = "10"

    @property
    def budget_int(self) -> int:
        try:
            return int(self.team_budget.replace("M", "").strip())
        except (ValueError, AttributeError):
            return 100

    @property
    def max_size_int(self) -> int:
        try:
            return int(self.max_team_number.strip())
        except (ValueError, AttributeError):
            return 10


class JoinPrivateLeagueRequest(BaseSchema):
    """Body Flutter sends to POST /api/private-leagues/join/."""
    join_code: str


class KickTeamCompatRequest(BaseSchema):
    """Body Flutter sends to POST /api/private-leagues/kick/."""
    team_id: int        # target user's auto_id
    league_id: int      # league auto_id


class StartLeagueCompatRequest(BaseSchema):
    """Body Flutter sends to POST /api/private-leagues/start_league/."""
    league_id: int      # league auto_id


class JoinPrivateLeagueResponse(BaseSchema):
    """Flutter navigates to waiting room using league_id from this response."""
    detail: str = "Successfully joined the league."
    league_id: int | None = None


# ── My Matches Today compat ───────────────────────────────────────────────────

class MatchPairCompatResponse(BaseSchema):
    """One pair in a head-to-head match — matches Flutter MatchPair.fromJson."""
    player_a_id: int | None = None
    player_a_name: str | None = None
    player_b_id: int | None = None
    player_b_name: str | None = None
    score_a: float = 0
    score_b: float = 0
    # Mongo LeagueMatch._id (as str) — lets Flutter call GET /api/v1/live/match/{id}
    # for this specific duel; the int fields above are only Django-compat auto_ids.
    match_object_id: str | None = None


class MyMatchTodayCompatResponse(BaseSchema):
    """Matches Flutter MyMatchTodayModel.fromJson()."""
    id: int = 0                 # match auto_id
    league_id: int = 0          # league auto_id
    league_name: str = ""
    match_day: int = 0
    match_type: str = "head_to_head"
    match_date: str = ""
    status: str = "upcoming"
    player_scores: list = []
    pairs: list[MatchPairCompatResponse] = []
    created_at: str = ""

    # Home "Night's Results" launch spec: only LIVE or FINAL are ever shown.
    # is_live_for_user: true only if the match is actually live AND this user
    # has an active premium/live-access subscription — otherwise it collapses
    # to FINAL (and this may be a fallback to the last *completed* match, not
    # necessarily today's, per spec §"last completed result").
    is_live_for_user: bool = False
    result_available: bool = False


# ── Match Result (Flutter Result tab) ────────────────────────────────────────

class PlayerSelectionItem(BaseSchema):
    """One player in a user's selection — shown on the court in Result > View Details."""
    id: str = ""
    name: str = ""
    position: str = ""
    score: int = 0


class PlayerScoreItem(BaseSchema):
    """One user's fantasy team score for a match day — matches Flutter PlayerScore.fromJson."""
    player_id: int = 0          # user auto_id
    team_name: str = ""         # user's fantasy team name
    username: str = ""
    total_points: int = 0
    selection: list[PlayerSelectionItem] = []


class MatchPairItem(BaseSchema):
    """One head-to-head duel card — matches Flutter MatchPair.fromJson."""
    player_a_id: int = 0
    player_a_name: str = ""
    player_b_id: int = 0
    player_b_name: str = ""
    score_a: int = 0
    score_b: int = 0
    # Mongo LeagueMatch._id (as str) — lets Flutter call GET /api/v1/live/match/{id}
    # for this specific duel; the int fields above are only Django-compat auto_ids.
    match_object_id: str | None = None


class MatchResultCompatResponse(BaseSchema):
    """Full match result for a league matchday — matches Flutter MatchResultModel.fromJson."""
    id: int = 0
    league_id: int = 0
    league_name: str = ""
    match_day: int = 0
    match_type: str = "head_to_head"
    match_date: str = ""
    status: str = "scheduled"
    player_scores: list[PlayerScoreItem] = []
    pairs: list[MatchPairItem] = []
    created_at: str = ""


# ── Player Selection (Flutter Build-Your-Team screen) ────────────────────────

class PlayersSelectionRequest(BaseSchema):
    """Body Flutter sends to POST /api/{type}-leagues/{id}/{matchDay}/players-selection/."""
    selected_players: list[dict]
    # Strategic bonuses (spec §4.4) — omitted/false = not activated. Not
    # applicable to the Global League (separate endpoint, no bonuses there).
    luxury_tax: bool = False
    chef_curry: bool = False
    sixth_man_player: dict | None = None


class PlayersSelectionGetResponse(BaseSchema):
    """Response for GET /api/{type}-leagues/{id}/{matchDay}/players-selection/."""
    selected_players: list[dict] = []
    # Team-builder lock countdown (spec: 3-state Confirm CTA gated on
    # now < lock_time). None = no game scheduled for this match day,
    # 0 = already locked, >0 = seconds until lock.
    lock_in_seconds: int | None = None
    # Echo back the saved bonus state so the app can restore it on reload.
    luxury_tax: bool = False
    chef_curry: bool = False
    sixth_man_player: dict | None = None


class PlayersSelectionPostResponse(BaseSchema):
    """Response for POST /api/{type}-leagues/{id}/{matchDay}/players-selection/."""
    match_id: int = 0
    total_points: float = 0.0
    current_balance: float = 0.0
    lock_in_seconds: int | None = None


# ── Games Today & Players Today compat (Flutter Build-Your-Team screen) ──────

class GameCompatResponse(BaseSchema):
    """Matches Flutter Game.fromJson()."""
    id: int = 0
    home_team: str = ""
    home_team_id: str = ""
    away_team: str = ""
    away_team_id: str = ""
    game_time: str = ""
    status: str = "Not Started"
    venue: str = ""
    timezone: str = "UTC"
    datetime_utc: str = ""
    home_score: int | None = None   # populated once game is live/final
    away_score: int | None = None


class PlayerCompatItem(BaseSchema):
    """Matches Flutter Player.fromJson() — {id, name, position, team, team_id, status, price, avg}."""
    id: str = ""
    name: str = ""
    position: str = ""
    team: str = ""
    team_id: str | None = None
    status: str = "OK"
    price: str = "0.0M"
    avg: int = 0                    # avg fantasy score rounded to int (DataScreen column)


# ── Today's Fantasy Scores (Flutter: MyMatchScreen > Todays Fantasy Players Score) ──

class PlayerTodayScoreItem(BaseSchema):
    """One player's fantasy score for today — MyMatchScreen lower section."""
    id: str = ""
    name: str = ""
    position: str = ""
    team: str = ""
    score: int = 0          # fantasy_score rounded to int


class PlayersTodayScoresResponse(BaseSchema):
    """GET /api/players-today-scores/ — sorted by score desc."""
    results: list[PlayerTodayScoreItem] = []


class PlayersTodayPageResponse(BaseSchema):
    """Paginated response Flutter reads: count, next, results."""
    count: int = 0
    next: str | None = None
    results: list[PlayerCompatItem] = []


# ── Leaderboard — Regular Season Standings ────────────────────────────────────

class StandingsEntry(BaseSchema):
    """One row in the Regular Season standings table."""
    rank: int = 0
    team_id: int = 0            # user auto_id
    team_name: str = ""
    wins: int = 0
    losses: int = 0
    points_for: float = 0.0    # PTS column — total FP scored
    points_against: float = 0.0 # PTC column — total FP conceded
    differential: float = 0.0   # +/- column
    is_playoff_spot: bool = False  # top-4 → blue border in Flutter


class StandingsResponse(BaseSchema):
    """Flutter Leaderboard tab — Regular Season view."""
    league_id: int = 0
    league_name: str = ""
    playoff_spots: int = 4
    teams: list[StandingsEntry] = []


# ── Leaderboard — Playoff Bracket ─────────────────────────────────────────────

class PlayoffGameResponse(BaseSchema):
    """One game result within a BO3 series."""
    game_number: int = 0
    score_a: int = 0
    score_b: int = 0
    winner_team: str = ""


class PlayoffSeriesResponse(BaseSchema):
    """One BO3 series — maps to one bracket card pair in Flutter."""
    series_index: int = 0
    round: str = ""
    team_a_id: int = 0
    team_a_name: str = ""
    team_b_id: int = 0
    team_b_name: str = ""
    wins_a: int = 0
    wins_b: int = 0
    games: list[PlayoffGameResponse] = []
    winner_id: int | None = None
    winner_name: str | None = None
    is_complete: bool = False


class PlayoffRoundResponse(BaseSchema):
    """One round in the bracket (quarter_final / semi_final / final)."""
    round_type: str = ""
    round_name: str = ""
    series: list[PlayoffSeriesResponse] = []


class PlayoffBracketResponse(BaseSchema):
    """Full playoff bracket — Flutter Leaderboard > Play-Off tab."""
    league_id: int = 0
    league_name: str = ""
    rounds: list[PlayoffRoundResponse] = []


# ── Player Info (Flutter: PlayerInfoScreen) ───────────────────────────────────

class PlayerSeasonAverages(BaseSchema):
    points: float = 0.0
    rebounds: float = 0.0
    assists: float = 0.0
    steals: float = 0.0
    turnovers: float = 0.0
    fantasy: float = 0.0


class PlayerInfoResponse(BaseSchema):
    """
    GET /api/players/{player_id}/info/
    Replaces the Random()-generated stats in PlayerInfoScreen.
    """
    id: str = ""
    name: str = ""
    position: str = ""
    team: str = ""
    team_id: str | None = None
    status: str = "Active"          # "Active" | "Out"
    current_value: str = "0M"       # formatted price string e.g. "29M"
    rating: float = 0.0             # avg_fantasy / 6, clamped [0, 10]
    season_averages: PlayerSeasonAverages = PlayerSeasonAverages()
    selected_today_pct: int = 0     # 0-100


# ── Global League player selection ────────────────────────────────────────────

class GlobalLeagueSelectionResponse(BaseSchema):
    """
    GET/POST /api/global-leagues/players-selection/
    Matches GlobalLeagueSelection.fromJson() in global_league_controller.dart.
    """
    match_day: int = 0
    selected_players: list[dict] = []
    total_points: int = 0
    max_balance: str = "100M"      # always "100M" for global
    current_balance: str = "100M"  # remaining after summing player prices

    # Home "NBA Global League" card launch spec: real validated/lock state
    # instead of the Flutter-side "5 players picked" proxy.
    lineup_submitted: bool = False
    lock_in_seconds: int | None = None

    # Weekly/monthly rank among all Global League members, from the daily
    # score archive. None until the user has at least joined the league.
    weekly_rank: int | None = None
    monthly_rank: int | None = None

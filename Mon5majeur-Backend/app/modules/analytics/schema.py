from datetime import date

from app.shared.base_schema import BaseSchema


# ── Block 1 — Top-bar counters ────────────────────────────────────────────────

class TopBarCountersResponse(BaseSchema):
    """The five quick numbers shown at the top of the dashboard."""

    downloads: int = 0                  # total user accounts ever created
    signups_today: int = 0              # of which created today (UTC)
    dau: int = 0                        # distinct users who validated a lineup tonight
    dau_7day_avg: float = 0.0           # mean nightly DAU over the last 7 match-nights
    lineups_tonight: int = 0            # validated lineups for tonight
    account_deletions: int = 0          # fulfilled erasure requests (all time)

    # Which NBA night "tonight" resolved to, so the dashboard can label the
    # figures honestly instead of implying they are live-to-the-second.
    night_date: date | None = None
    # Nights actually used for the rolling average (may be < 7 early in the
    # season) — prevents a misleadingly low average being read as a drop.
    dau_7day_nights_used: int = 0


# ── Block 2 — Cohort retention grid ───────────────────────────────────────────

class CohortRow(BaseSchema):
    """One signup-week row of the retention grid."""

    cohort_week: date                   # Monday of the signup week
    cohort_size: int = 0
    # Keyed by day offset ("1", "3", "7", "14", "30", "60", "90").
    # A missing key means "not measurable yet" (the empty triangle) and must
    # render blank — NOT 0%, which would read as total churn.
    retained: dict[str, int] = {}
    rates: dict[str, float] = {}        # retained / cohort_size, 0..1


class CohortRetentionResponse(BaseSchema):
    day_offsets: list[int] = []
    rows: list[CohortRow] = []


# ── Block 3 — Activation ──────────────────────────────────────────────────────

class ActivationResponse(BaseSchema):
    """Share of signups who ever validated a first lineup (lifetime flag)."""

    total_users: int = 0
    activated_users: int = 0
    activation_rate: float = 0.0        # 0..1


# ── Block 4 — Lineup volume per night ─────────────────────────────────────────

class NightVolume(BaseSchema):
    night_date: date
    lineups_count: int = 0


class LineupVolumeResponse(BaseSchema):
    nights: list[NightVolume] = []


# ── Block 5 — Players in a private league ─────────────────────────────────────

class PrivateLeaguePlayersResponse(BaseSchema):
    players_in_private: int = 0
    total_players: int = 0              # distinct players over the same window
    nights_considered: int = 0


# ── Everything at once (one call for the whole dashboard) ─────────────────────

class RetentionOverviewResponse(BaseSchema):
    counters: TopBarCountersResponse
    cohorts: CohortRetentionResponse
    activation: ActivationResponse
    lineup_volume: LineupVolumeResponse
    private_league: PrivateLeaguePlayersResponse

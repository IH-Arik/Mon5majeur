"""
Retention analytics (Admin Dashboard — Retention lean spec, Season 1).

THE ONE RULE (spec §00): every metric counts a **validated lineup**
("compo") — never "app opened", never "is a member". A user who opened the
app but never submitted a 5-player lineup is not active and not retained,
anywhere in this module.

"Night" is an NBA match night (the US/EST date Goalserve reports), never a
calendar day, and "per night" metrics only ever run over nights that
actually had NBA games.

Source of truth for a validated lineup is `FlutterPlayerSelection` — the
collection the mobile app actually writes when a user taps Confirm. The
older `LineupSubmission`/`LineupSlot` pair belongs to the unused /api/v1
lineup API and is deliberately NOT counted here; counting it would
double-count some nights and miss most others.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

from app.core.logging import get_logger
from app.modules.analytics.model import AccountDeletionLog
from app.modules.analytics.schema import (
    ActivationResponse,
    CohortRetentionResponse,
    CohortRow,
    LineupVolumeResponse,
    NightVolume,
    PrivateLeaguePlayersResponse,
    RetentionOverviewResponse,
    TopBarCountersResponse,
)
from app.modules.leagues.constants import LEAGUE_TYPE_PRIVATE
from app.modules.leagues.model import League
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.model import NBAGame
from app.modules.users.model import User

logger = get_logger(__name__)

# Day offsets of the cohort grid (spec block 2).
COHORT_DAY_OFFSETS = [1, 3, 7, 14, 30, 60, 90]

# Rolling window sizes fixed by the spec.
DAU_ROLLING_NIGHTS = 7
LINEUP_VOLUME_NIGHTS = 30
PRIVATE_LEAGUE_NIGHTS = 30

# A lineup counts only once it is a complete 5-player compo. Both submit
# paths already reject anything else, so this is a belt-and-braces filter
# that also protects the figures from any legacy/partial row.
LINEUP_SIZE = 5

# Only rows that have been assigned their NBA night can be counted per
# night. Legacy rows written before `nba_date` existed are backfilled by
# scripts/backfill_lineup_nba_date.py — until that runs they are simply
# absent from per-night figures rather than silently mis-dated.
_VALIDATED_LINEUP_FILTER: dict = {
    f"selected_players.{LINEUP_SIZE - 1}": {"$exists": True},
    f"selected_players.{LINEUP_SIZE}": {"$exists": False},
}


def _utc_today() -> date:
    return datetime.now(timezone.utc).date()


class RetentionAnalyticsService:
    """Computes the five dashboard blocks. Read-only — never mutates data."""

    # ── shared building blocks ────────────────────────────────────────────

    async def match_nights(self, limit: int | None = None) -> list[date]:
        """Distinct NBA match nights, most recent first.

        This is the spec's `match_nights` table: nights that actually had
        games, taken from the Goalserve-fed NBAGame collection. Future
        fixtures are excluded — a scheduled night that has not happened yet
        would otherwise drag every "per night" average down.
        """
        today = _utc_today()
        pipeline: list[dict] = [
            {"$match": {"nba_date": {"$lte": datetime.combine(today, datetime.min.time())}}},
            {"$group": {"_id": "$nba_date"}},
            {"$sort": {"_id": -1}},
        ]
        if limit is not None:
            pipeline.append({"$limit": limit})

        rows = await NBAGame.aggregate(pipeline).to_list()
        return [_as_date(r["_id"]) for r in rows if r.get("_id") is not None]

    async def current_night(self) -> date | None:
        """The night the dashboard means by "tonight": the most recent match
        night that has already started. Returns None before the season's
        first game, so callers can render "—" rather than a fake zero."""
        nights = await self.match_nights(limit=1)
        return nights[0] if nights else None

    async def _private_league_ids(self) -> list:
        leagues = await League.find(League.type == LEAGUE_TYPE_PRIVATE).to_list()
        return [lg.id for lg in leagues]

    # ── block 1 — top-bar counters ────────────────────────────────────────

    async def top_bar_counters(self) -> TopBarCountersResponse:
        today = _utc_today()
        night = await self.current_night()

        downloads = await User.find_all().count()
        signups_today = await User.find(
            User.created_at >= datetime.combine(today, datetime.min.time(), tzinfo=timezone.utc)
        ).count()

        lineups_tonight = 0
        dau = 0
        if night is not None:
            lineups_tonight = await self._lineups_on(night)
            dau = await self._dau_on(night)

        rolling_nights = await self.match_nights(limit=DAU_ROLLING_NIGHTS)
        dau_values = [await self._dau_on(n) for n in rolling_nights]
        dau_avg = round(sum(dau_values) / len(dau_values), 1) if dau_values else 0.0

        deletions = await AccountDeletionLog.find_all().count()

        return TopBarCountersResponse(
            downloads=downloads,
            signups_today=signups_today,
            dau=dau,
            dau_7day_avg=dau_avg,
            dau_7day_nights_used=len(dau_values),
            lineups_tonight=lineups_tonight,
            account_deletions=deletions,
            night_date=night,
        )

    async def _lineups_on(self, night: date) -> int:
        return await FlutterPlayerSelection.find(
            {"nba_date": _as_datetime(night), **_VALIDATED_LINEUP_FILTER}
        ).count()

    async def _dau_on(self, night: date) -> int:
        """Distinct users with ≥1 validated lineup on that night. Distinct —
        a user in three leagues on one night is one active user, not three."""
        rows = await FlutterPlayerSelection.aggregate(
            [
                {"$match": {"nba_date": _as_datetime(night), **_VALIDATED_LINEUP_FILTER}},
                {"$group": {"_id": "$user_id"}},
                {"$count": "n"},
            ]
        ).to_list()
        return rows[0]["n"] if rows else 0

    # ── block 2 — cohort retention grid (the core) ────────────────────────

    async def cohort_retention(self) -> CohortRetentionResponse:
        """Rows = signup week, columns = D1/D3/D7/D14/D30/D60/D90.

        Retained at day n = the user validated ≥1 lineup on the calendar day
        (signup_date + n).

        A cell is only reported once EVERY user in that cohort has actually
        had the chance to reach day n. Reporting it earlier would divide by
        the full cohort while part of it could not possibly have played yet,
        which reads as a collapse in retention that never happened. Cells
        that are not yet measurable are omitted — that is the expected empty
        triangle, and the dashboard must render it blank, not 0%.
        """
        today = _utc_today()

        users = await User.find_all().to_list()
        if not users:
            return CohortRetentionResponse(day_offsets=COHORT_DAY_OFFSETS, rows=[])

        # (user_id -> set of nights they validated a lineup on). Small enough
        # to hold in memory at this scale, and far easier to verify against
        # the spec than an equivalent 7-way conditional aggregation.
        nights_by_user: dict[object, set[date]] = defaultdict(set)
        rows = await FlutterPlayerSelection.aggregate(
            [
                {"$match": {"nba_date": {"$ne": None}, **_VALIDATED_LINEUP_FILTER}},
                {"$group": {"_id": {"u": "$user_id", "d": "$nba_date"}}},
            ]
        ).to_list()
        for r in rows:
            key = r["_id"]
            nights_by_user[key["u"]].add(_as_date(key["d"]))

        cohorts: dict[date, list] = defaultdict(list)
        for u in users:
            signup = u.created_at.date()
            cohorts[_week_start(signup)].append((u.id, signup))

        out: list[CohortRow] = []
        for week in sorted(cohorts.keys()):
            members = cohorts[week]
            size = len(members)
            latest_signup = max(s for _, s in members)

            retained: dict[str, int] = {}
            rates: dict[str, float] = {}
            for n in COHORT_DAY_OFFSETS:
                if latest_signup + timedelta(days=n) > today:
                    continue  # not measurable yet — leave the cell empty
                hits = sum(
                    1
                    for uid, signup in members
                    if (signup + timedelta(days=n)) in nights_by_user.get(uid, ())
                )
                retained[str(n)] = hits
                rates[str(n)] = round(hits / size, 4) if size else 0.0

            out.append(
                CohortRow(cohort_week=week, cohort_size=size, retained=retained, rates=rates)
            )

        return CohortRetentionResponse(day_offsets=COHORT_DAY_OFFSETS, rows=out)

    # ── block 3 — activation ──────────────────────────────────────────────

    async def activation(self) -> ActivationResponse:
        """Lifetime OFF→ON flag: has this signup EVER validated a lineup.

        Deliberately ignores `nba_date`, so it stays correct even for rows
        that predate that field — "ever played" does not depend on knowing
        which night it was.
        """
        total = await User.find_all().count()
        rows = await FlutterPlayerSelection.aggregate(
            [
                {"$match": _VALIDATED_LINEUP_FILTER},
                {"$group": {"_id": "$user_id"}},
                {"$count": "n"},
            ]
        ).to_list()
        activated = rows[0]["n"] if rows else 0

        return ActivationResponse(
            total_users=total,
            activated_users=activated,
            activation_rate=round(activated / total, 4) if total else 0.0,
        )

    # ── block 4 — lineup volume per night ─────────────────────────────────

    async def lineup_volume(self, nights: int = LINEUP_VOLUME_NIGHTS) -> LineupVolumeResponse:
        """Validated lineups per night over the last N match-nights.

        Nights with zero lineups are still returned: an empty night is the
        exact signal this block exists to surface, and dropping it would
        hide the outage it represents.
        """
        recent = await self.match_nights(limit=nights)
        if not recent:
            return LineupVolumeResponse(nights=[])

        counts = {
            _as_date(r["_id"]): r["n"]
            for r in await FlutterPlayerSelection.aggregate(
                [
                    {
                        "$match": {
                            "nba_date": {"$in": [_as_datetime(d) for d in recent]},
                            **_VALIDATED_LINEUP_FILTER,
                        }
                    },
                    {"$group": {"_id": "$nba_date", "n": {"$sum": 1}}},
                ]
            ).to_list()
        }

        return LineupVolumeResponse(
            nights=[
                NightVolume(night_date=d, lineups_count=counts.get(d, 0))
                for d in sorted(recent)
            ]
        )

    # ── block 5 — players in a private league ─────────────────────────────

    async def private_league_players(
        self, nights: int = PRIVATE_LEAGUE_NIGHTS
    ) -> PrivateLeaguePlayersResponse:
        """Headcount of players active in ≥1 private league over the window.

        A count, not a percentage (spec). Solo and private are not
        exclusive — a player in both is counted here and in the total.
        """
        recent = await self.match_nights(limit=nights)
        if not recent:
            return PrivateLeaguePlayersResponse(nights_considered=0)

        night_filter = {"$in": [_as_datetime(d) for d in recent]}
        private_ids = await self._private_league_ids()

        private_players = 0
        if private_ids:
            rows = await FlutterPlayerSelection.aggregate(
                [
                    {
                        "$match": {
                            "nba_date": night_filter,
                            "league_id": {"$in": private_ids},
                            **_VALIDATED_LINEUP_FILTER,
                        }
                    },
                    {"$group": {"_id": "$user_id"}},
                    {"$count": "n"},
                ]
            ).to_list()
            private_players = rows[0]["n"] if rows else 0

        total_rows = await FlutterPlayerSelection.aggregate(
            [
                {"$match": {"nba_date": night_filter, **_VALIDATED_LINEUP_FILTER}},
                {"$group": {"_id": "$user_id"}},
                {"$count": "n"},
            ]
        ).to_list()

        return PrivateLeaguePlayersResponse(
            players_in_private=private_players,
            total_players=total_rows[0]["n"] if total_rows else 0,
            nights_considered=len(recent),
        )

    # ── everything at once ────────────────────────────────────────────────

    async def overview(self) -> RetentionOverviewResponse:
        return RetentionOverviewResponse(
            counters=await self.top_bar_counters(),
            cohorts=await self.cohort_retention(),
            activation=await self.activation(),
            lineup_volume=await self.lineup_volume(),
            private_league=await self.private_league_players(),
        )


# ── date helpers ──────────────────────────────────────────────────────────────
#
# Mongo has no date-only type: Beanie stores `date` fields as a BSON datetime
# at midnight. Queries must therefore be built with datetimes and results
# converted back, or every per-night match silently returns nothing.

def _as_datetime(d: date) -> datetime:
    return datetime.combine(d, datetime.min.time())


def _as_date(value: datetime | date) -> date:
    return value.date() if isinstance(value, datetime) else value


def _week_start(d: date) -> date:
    """Monday of that ISO week — the cohort bucket (spec: date_trunc('week'))."""
    return d - timedelta(days=d.weekday())

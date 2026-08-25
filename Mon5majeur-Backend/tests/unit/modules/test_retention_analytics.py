"""
Unit tests for the retention analytics service (admin dashboard, block 2-3).

The cohort grid is the part of the dashboard most easily wrong in ways that
still *look* plausible — an off-by-one on the day offset, or filling the
"not yet measurable" cells with 0% so a healthy young cohort reads as total
churn. These tests pin that behaviour down against the spec without needing
a database: the two data sources the service reads are stubbed.

Run standalone (the repo's tests/conftest.py is legacy SQLAlchemy and would
otherwise fail collection):
    ./.venv/Scripts/python.exe -m pytest tests/unit/modules/test_retention_analytics.py --noconftest
"""
from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.modules.analytics.service import (
    COHORT_DAY_OFFSETS,
    RetentionAnalyticsService,
    _week_start,
)


# ── stubbing helpers ──────────────────────────────────────────────────────────

class _Result:
    def __init__(self, rows):
        self._rows = rows

    async def to_list(self):
        return self._rows

    async def count(self):
        return len(self._rows)


def _user(uid: str, created: date):
    return SimpleNamespace(
        id=uid,
        created_at=datetime.combine(created, datetime.min.time(), tzinfo=timezone.utc),
    )


def _patch_sources(monkeypatch, users, night_pairs):
    """night_pairs: iterable of (user_id, date) — a validated lineup that night."""
    from app.modules.analytics import service as svc

    monkeypatch.setattr(svc.User, "find_all", lambda *a, **k: _Result(users))
    monkeypatch.setattr(
        svc.FlutterPlayerSelection,
        "aggregate",
        lambda *a, **k: _Result(
            [
                {"_id": {"u": uid, "d": datetime.combine(d, datetime.min.time())}}
                for uid, d in night_pairs
            ]
        ),
    )


def _run(coro):
    return asyncio.run(coro)


# ── week bucketing ────────────────────────────────────────────────────────────

def test_week_start_buckets_to_monday():
    # 2026-08-20 is a Thursday; its ISO week starts Monday 2026-08-17.
    assert _week_start(date(2026, 8, 20)) == date(2026, 8, 17)
    assert _week_start(date(2026, 8, 17)) == date(2026, 8, 17)
    # Sunday still belongs to the week that began the previous Monday.
    assert _week_start(date(2026, 8, 23)) == date(2026, 8, 17)


# ── the retention rule itself ─────────────────────────────────────────────────

def test_retained_counts_lineup_on_exactly_signup_plus_n(monkeypatch):
    """Retained at day n means a lineup on signup_date + n — not 'within n'."""
    signup = date.today() - timedelta(days=200)  # old enough that all offsets close
    users = [_user("u1", signup), _user("u2", signup)]

    _patch_sources(
        monkeypatch,
        users,
        [
            ("u1", signup + timedelta(days=1)),   # D1 hit
            ("u1", signup + timedelta(days=7)),   # D7 hit
            ("u2", signup + timedelta(days=2)),   # day 2 — must not count for D1 or D3
        ],
    )

    res = _run(RetentionAnalyticsService().cohort_retention())
    row = res.rows[0]

    assert row.cohort_size == 2
    assert row.retained["1"] == 1          # only u1
    assert row.retained["3"] == 0          # u2's day-2 lineup must NOT leak into D3
    assert row.retained["7"] == 1
    assert row.rates["1"] == pytest.approx(0.5)


def test_multiple_lineups_same_night_count_once(monkeypatch):
    """A user playing three leagues on one night is one retained user."""
    signup = date.today() - timedelta(days=200)
    users = [_user("u1", signup)]
    # The service de-duplicates via a set of (user, night); feeding the same
    # pair repeatedly mimics one user with several leagues that night.
    _patch_sources(
        monkeypatch,
        users,
        [("u1", signup + timedelta(days=1))] * 3,
    )

    row = _run(RetentionAnalyticsService().cohort_retention()).rows[0]
    assert row.retained["1"] == 1
    assert row.rates["1"] == pytest.approx(1.0)


# ── the empty triangle ────────────────────────────────────────────────────────

def test_young_cohort_leaves_unreachable_offsets_blank(monkeypatch):
    """A cohort that signed up 2 days ago cannot have a D7 figure yet.

    The cell must be ABSENT, not 0 — a zero would render as "0% retention"
    and read as catastrophic churn for a cohort that is simply too young.
    """
    signup = date.today() - timedelta(days=2)
    _patch_sources(monkeypatch, [_user("u1", signup)], [])

    row = _run(RetentionAnalyticsService().cohort_retention()).rows[0]

    assert "1" in row.retained          # day 1 has passed — measurable
    assert "3" not in row.retained      # day 3 has not
    assert "7" not in row.retained
    assert "90" not in row.retained


def test_cell_waits_for_the_whole_cohort(monkeypatch):
    """The offset closes only once the LAST signup of the week reached it.

    Otherwise the rate is divided by the full cohort while some members
    could not possibly have played yet — an artificial dip.
    """
    today = date.today()
    week_monday = _week_start(today)
    # Two users in the same week: one from Monday, one from today.
    early, late = week_monday, today
    if early == late:  # running on a Monday — force a spread
        early = week_monday - timedelta(days=7)
        week_monday = _week_start(early)

    _patch_sources(monkeypatch, [_user("early", early), _user("late", late)], [])

    res = _run(RetentionAnalyticsService().cohort_retention())
    row = next(r for r in res.rows if r.cohort_week == _week_start(late))

    days_since_last_signup = (today - late).days
    for n in COHORT_DAY_OFFSETS:
        if n <= days_since_last_signup:
            assert str(n) in row.retained, f"D{n} should be measurable"
        else:
            assert str(n) not in row.retained, f"D{n} must stay blank"


def test_cohorts_are_split_by_signup_week(monkeypatch):
    old = date.today() - timedelta(days=200)
    older = old - timedelta(days=14)
    _patch_sources(monkeypatch, [_user("a", old), _user("b", older)], [])

    res = _run(RetentionAnalyticsService().cohort_retention())
    weeks = [r.cohort_week for r in res.rows]

    assert len(res.rows) == 2
    assert weeks == sorted(weeks)  # chronological, oldest first
    assert all(r.cohort_size == 1 for r in res.rows)


def test_no_users_yields_empty_grid(monkeypatch):
    _patch_sources(monkeypatch, [], [])
    res = _run(RetentionAnalyticsService().cohort_retention())
    assert res.rows == []
    assert res.day_offsets == COHORT_DAY_OFFSETS


# ── activation ────────────────────────────────────────────────────────────────

def test_activation_rate_is_distinct_users_over_total(monkeypatch):
    from app.modules.analytics import service as svc

    monkeypatch.setattr(svc.User, "find_all", lambda *a, **k: _Result([1, 2, 3, 4]))
    monkeypatch.setattr(
        svc.FlutterPlayerSelection, "aggregate", lambda *a, **k: _Result([{"n": 2}])
    )

    res = _run(RetentionAnalyticsService().activation())

    assert res.total_users == 4
    assert res.activated_users == 2
    assert res.activation_rate == pytest.approx(0.5)


def test_activation_rate_is_zero_not_error_with_no_users(monkeypatch):
    from app.modules.analytics import service as svc

    monkeypatch.setattr(svc.User, "find_all", lambda *a, **k: _Result([]))
    monkeypatch.setattr(svc.FlutterPlayerSelection, "aggregate", lambda *a, **k: _Result([]))

    res = _run(RetentionAnalyticsService().activation())
    assert res.activation_rate == 0.0

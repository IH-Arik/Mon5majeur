"""
Score paywall (QA 15/09/2026 item 4) and roster name matching (item 2).

Run standalone (tests/conftest.py is legacy SQLAlchemy):
    python -m pytest tests/unit/modules/test_score_visibility.py --noconftest
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from types import SimpleNamespace

from app.modules.leagues.score_visibility import (
    release_iso,
    score_release_at,
    scores_hidden,
)
from app.modules.players.espn_roster import normalize_name

NIGHT = date(2026, 9, 8)  # NBA night; games end in the small hours of the 9th


def _free():
    return SimpleNamespace(is_superuser=False, premium_until=None)


def _premium():
    return SimpleNamespace(
        is_superuser=False, premium_until=datetime(2099, 1, 1, tzinfo=timezone.utc)
    )


def _at(hour_utc, minute=0, day=9):
    return datetime(2026, 9, day, hour_utc, minute, tzinfo=timezone.utc)


def test_release_is_9am_paris_the_morning_after_the_night():
    # Paris is UTC+2 in September, so 09:00 Paris == 07:00 UTC on the 9th.
    assert score_release_at(NIGHT) == _at(7)


def test_release_follows_paris_dst_in_winter():
    # In January Paris is UTC+1: 09:00 Paris == 08:00 UTC.
    assert score_release_at(date(2027, 1, 14)) == datetime(
        2027, 1, 15, 8, 0, tzinfo=timezone.utc
    )


def test_non_subscriber_never_sees_live_scores():
    assert scores_hidden(_free(), status="live", nba_date=NIGHT, now=_at(3))
    assert scores_hidden(_free(), status="live", nba_date=NIGHT, now=_at(23, day=20))


def test_non_subscriber_sees_finished_scores_only_from_9am_paris():
    assert scores_hidden(_free(), status="completed", nba_date=NIGHT, now=_at(6, 59))
    assert not scores_hidden(_free(), status="completed", nba_date=NIGHT, now=_at(7, 0))
    assert not scores_hidden(_free(), status="completed", nba_date=NIGHT, now=_at(12, 0, day=20))


def test_subscriber_and_admin_always_see_scores():
    assert not scores_hidden(_premium(), status="live", nba_date=NIGHT, now=_at(3))
    assert not scores_hidden(_premium(), status="completed", nba_date=NIGHT, now=_at(3))
    admin = SimpleNamespace(is_superuser=True, premium_until=None)
    assert not scores_hidden(admin, status="live", nba_date=NIGHT, now=_at(3))


def test_match_not_started_has_nothing_to_hide():
    for status in ("upcoming", "scheduled"):
        assert not scores_hidden(_free(), status=status, nba_date=NIGHT, now=_at(3))


def test_release_iso_is_none_without_a_date():
    assert release_iso(None) is None
    assert release_iso(NIGHT).startswith("2026-09-09T07:00:00")


# ── roster name matching ──────────────────────────────────────────────────────

def test_normalize_name_ignores_accents_case_punctuation_and_suffixes():
    assert normalize_name("Nikola Jokić") == normalize_name("nikola jokic")
    assert normalize_name("Jaren Jackson Jr.") == normalize_name("Jaren Jackson")
    assert normalize_name("P.J. Washington") == normalize_name("PJ Washington") or (
        normalize_name("P.J. Washington") == "p j washington"
    )
    assert normalize_name("Gary Payton II") == normalize_name("Gary Payton")
    assert normalize_name("") == ""


# ── standings honour the paywall (viewer-filtered tallies) ────────────────────

import asyncio
import copy


class _Rows:
    def __init__(self, rows):
        self._rows = rows

    async def to_list(self):
        return self._rows


def _member(uid):
    m = SimpleNamespace(
        user_id=uid, wins=5, losses=5, points_for=999.0, points_against=999.0
    )
    m.model_copy = lambda m=m: copy.copy(m)
    return m


def _match(home, away, night, hs, as_, winner, status="completed"):
    return SimpleNamespace(
        home_user_id=home, away_user_id=away, nba_date=night, home_score=hs,
        away_score=as_, winner_id=winner, status=status,
    )


def _patch_league(monkeypatch, members, matches):
    from app.modules.leagues import leaderboard_service as ls

    monkeypatch.setattr(ls.LeagueMembership, "find", lambda *a, **k: _Rows(members))
    monkeypatch.setattr(ls.LeagueMatch, "find", lambda *a, **k: _Rows(matches))
    return ls


def test_tally_matches_counts_wins_losses_and_points():
    from app.modules.leagues.leaderboard_service import tally_matches

    a = SimpleNamespace(wins=0, losses=0, points_for=0.0, points_against=0.0)
    b = SimpleNamespace(wins=0, losses=0, points_for=0.0, points_against=0.0)
    tally_matches({"a": a, "b": b}, [_match("a", "b", NIGHT, 100.0, 90.0, "a")])
    assert (a.wins, a.losses, a.points_for, a.points_against) == (1, 0, 100.0, 90.0)
    assert (b.wins, b.losses, b.points_for, b.points_against) == (0, 1, 90.0, 100.0)


def test_non_subscriber_standings_leave_out_unreleased_matches(monkeypatch):
    """A match finished last night (before 09:00 Paris) must not move the
    non-subscriber's W/L or points; an older one still does."""
    from unittest import mock

    old_night = date(2026, 8, 1)  # long released relative to the mocked clock
    fresh = date(2026, 9, 8)
    members = [_member("a"), _member("b")]
    matches = [
        _match("a", "b", old_night, 100.0, 90.0, "a"),
        _match("b", "a", fresh, 120.0, 80.0, "b"),
    ]
    ls = _patch_league(monkeypatch, members, matches)

    with mock.patch(
        "app.modules.leagues.score_visibility.datetime",
        wraps=datetime,
    ) as dt:
        dt.now.return_value = _at(5, 0)  # 07:00 Paris on the 9th: still hidden
        out = asyncio.run(ls.viewer_memberships("L", _free()))
    a = next(m for m in out if m.user_id == "a")
    b = next(m for m in out if m.user_id == "b")
    assert (a.wins, a.losses, a.points_for) == (1, 0, 100.0)
    assert (b.wins, b.losses, b.points_for) == (0, 1, 90.0)
    # the stored (real) totals are untouched
    assert members[0].wins == 5 and members[0].points_for == 999.0


def test_subscriber_gets_the_stored_totals(monkeypatch):
    members = [_member("a")]
    ls = _patch_league(monkeypatch, members, [])
    out = asyncio.run(ls.viewer_memberships("L", _premium()))
    assert out[0].wins == 5 and out[0].points_for == 999.0

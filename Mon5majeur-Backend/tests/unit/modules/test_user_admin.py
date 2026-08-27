"""
Unit tests for the admin User Management additions: the derived `status`
label (Active/Pending/Banned/Inactive must never conflate "banned by admin"
with "self-deleted by user", both of which set is_active=False) and the
stats() aggregation.

Run standalone (the repo's tests/conftest.py is legacy SQLAlchemy):
    ./.venv/Scripts/python.exe -m pytest tests/unit/modules/test_user_admin.py --noconftest
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from app.modules.users.model import derive_user_status
from app.modules.users.service import UserService


def _status(**overrides) -> str:
    defaults = dict(is_active=True, is_verified=True, is_banned=False)
    defaults.update(overrides)
    return derive_user_status(**defaults)


# ── status derivation ──────────────────────────────────────────────────────────

def test_status_active_by_default():
    assert _status() == "Active"


def test_status_pending_when_unverified():
    assert _status(is_verified=False) == "Pending"


def test_status_inactive_when_self_deleted():
    """Soft self-delete (profile_router.delete_account) sets is_active=False
    without touching is_banned — must read as Inactive, not Banned."""
    assert _status(is_active=False) == "Inactive"


def test_status_banned_takes_priority():
    """An admin-banned user must show Banned even if the account also
    happens to be inactive/unverified — banned is the more specific state."""
    assert _status(is_banned=True) == "Banned"
    assert _status(is_banned=True, is_active=False) == "Banned"
    assert _status(is_banned=True, is_verified=False) == "Banned"


# ── stats() ────────────────────────────────────────────────────────────────────

class _Result:
    def __init__(self, n):
        self._n = n

    async def count(self):
        return self._n


class _AggResult:
    def __init__(self, rows):
        self._rows = rows

    async def to_list(self):
        return self._rows


def _run(coro):
    return asyncio.run(coro)


def test_stats_counts_map_to_the_right_fields(monkeypatch):
    from app.modules.users import service as svc
    from app.modules.lineups import compat_model as lineup_mod

    # UserService.stats() calls User.find(...) twice, in order: banned, then
    # new signups — return each call's count by call order rather than by
    # inspecting the Beanie query expression (too brittle to match on).
    find_call_results = iter([_Result(2), _Result(3)])

    monkeypatch.setattr(svc.User, "find_all", lambda: _Result(10))
    monkeypatch.setattr(svc.User, "find", lambda *a, **k: next(find_call_results))
    monkeypatch.setattr(
        lineup_mod.FlutterPlayerSelection,
        "aggregate",
        lambda *a, **k: _AggResult([{"n": 4}]),
    )

    result = _run(UserService(repo=None).stats())

    assert result.total_users == 10
    assert result.banned_users == 2
    assert result.new_signups_30d == 3
    assert result.monthly_active_users == 4


def test_stats_monthly_active_is_zero_not_error_with_no_lineups(monkeypatch):
    from app.modules.users import service as svc
    from app.modules.lineups import compat_model as lineup_mod

    monkeypatch.setattr(svc.User, "find_all", lambda: _Result(0))
    monkeypatch.setattr(svc.User, "find", lambda *a, **k: _Result(0))
    monkeypatch.setattr(
        lineup_mod.FlutterPlayerSelection, "aggregate", lambda *a, **k: _AggResult([])
    )

    result = _run(UserService(repo=None).stats())
    assert result.monthly_active_users == 0

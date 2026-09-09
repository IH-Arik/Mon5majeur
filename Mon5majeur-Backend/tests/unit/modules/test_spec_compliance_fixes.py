"""
Regression tests for the four spec deviations found in the backend audit
against Mon5Majeur_Backend.pdf v1.0.

Each test pins the *rule the spec states*, not the implementation, so a
future refactor that quietly reverts the behaviour fails here.

Run standalone (the repo's tests/conftest.py is legacy SQLAlchemy and would
otherwise fail collection):
    ./.venv/Scripts/python.exe -m pytest tests/unit/modules/test_spec_compliance_fixes.py --noconftest
"""
from __future__ import annotations

import asyncio
import inspect
from datetime import date, datetime, timedelta, timezone

import pytest
import pytz
from apscheduler.triggers.cron import CronTrigger

from app.cron.scheduler import live_poll_trigger
from app.modules.notifications.duel_context import DuelContext, _display_name

PARIS = pytz.timezone("Europe/Paris")


def _run(coro):
    return asyncio.run(coro)


# ── §5.3 — account deletion must erase, not deactivate ────────────────────────

def test_the_endpoint_the_app_calls_performs_a_full_erasure():
    """The Flutter app deletes via /api/UserProfiles/, so the erasure has to
    live there. Deferring to /api/v1/users/me would leave every shipped
    build merely deactivating accounts."""
    from app.modules.users import profile_router

    src = inspect.getsource(profile_router.delete_account)
    assert "delete_user" in src, "must call the hard-delete service"
    assert "is_active=False" not in src, "must not fall back to deactivation"


def test_erasure_covers_every_store_holding_user_data():
    """Spec §5.3: "erase ALL data (profile, lineups, history, payment-linked
    data)". A store missing from this list survives the deletion."""
    from app.modules.users.service import UserService

    src = inspect.getsource(UserService.delete_user)
    for store in (
        "LineupSubmission",
        "LineupSlot",
        "FlutterPlayerSelection",
        "LeagueMembership",
        "GlobalLeagueDailyScore",
        "UserBonusQuota",
        "UserBonusInventory",
        "TokenTransaction",
        "TokenWallet",
        "Notification",
        "OTPToken",
        "RefreshToken",
        "SupportTicket",       # carries the user's email and pseudo
        "GlobalLeagueReward",
        "CompetitionEntry",
        "FantasyTeam",
    ):
        assert store in src, f"{store} is not erased on account deletion"


def test_deletion_is_audited_before_the_data_goes():
    """The retention dashboard counts churn from AccountDeletionLog. Written
    after the erasure there would be nothing left to describe."""
    from app.modules.users.service import UserService

    src = inspect.getsource(UserService.delete_user)
    log_at = src.index("AccountDeletionLog")
    first_delete = src.index(".delete()")
    assert log_at < first_delete, "the audit row must precede the deletions"


# ── §4.5 — premium live score refreshes every minute ──────────────────────────

def test_live_poller_runs_every_minute_during_the_nba_window():
    trigger = live_poll_trigger()

    mid_game = PARIS.localize(datetime(2026, 1, 15, 2, 30, 0))
    nxt = trigger.get_next_fire_time(None, mid_game)
    assert nxt - mid_game <= timedelta(minutes=1), "must poll at least once a minute"


def test_live_poller_covers_early_tip_offs():
    """Spec §4.1: some slates tip off as early as ~19:30 Paris. A window
    starting at 01:00 would leave those games without a live score."""
    trigger = live_poll_trigger()

    # A 19:30 tip-off must already be covered: the poller has to fire at or
    # before it, not wait for a window that opens later in the night.
    tip_off = PARIS.localize(datetime(2026, 1, 18, 19, 30, 0))
    just_before = PARIS.localize(datetime(2026, 1, 18, 19, 29, 0))
    assert trigger.get_next_fire_time(None, just_before) <= tip_off


def test_live_poller_is_idle_during_the_day():
    """No NBA game runs at midday Paris; polling then only burns quota."""
    trigger = live_poll_trigger()

    noon = PARIS.localize(datetime(2026, 1, 15, 12, 0, 0))
    assert trigger.get_next_fire_time(None, noon).hour == 19


def test_live_job_skips_the_external_call_when_nothing_is_in_progress():
    """Every-minute scheduling only works if an idle night costs nothing —
    the Goalserve call must be gated on a game actually being in progress."""
    from app.cron import jobs

    src = inspect.getsource(jobs.sync_live_games_job)
    worth = src.index("_worth_polling")
    call = src.index("sync_scores_for_date")
    assert worth < call, "the in-progress check must gate the Goalserve call"


# ── §4.7 / §4.8 — the "player is OUT" alert ───────────────────────────────────

def test_out_alert_reaches_a_holder_found_only_in_the_app_store(monkeypatch):
    """The team builder saves to FlutterPlayerSelection; querying only
    LineupSlot found nobody, so the alert silently reached no one.

    Asserted through behaviour rather than by grepping the source: a holder
    that exists *only* in FlutterPlayerSelection must still be notified.
    """
    from app.modules.notifications.service import NotificationService
    from app.modules.lineups import compat_model, model as lineup_model

    class _Sel:
        user_id = "u1"

    class _FlutterStore:
        @staticmethod
        def find(*a, **k):
            class _R:
                async def to_list(self):
                    return [_Sel()]
            return _R()

    class _EmptySlots:
        @staticmethod
        def find(*a, **k):
            class _R:
                async def to_list(self):
                    return []
            return _R()
        # class-level fields compared in the query
        player_id = None
        nba_date = None
        score_finalized = None

    monkeypatch.setattr(compat_model, "FlutterPlayerSelection", _FlutterStore)
    monkeypatch.setattr(lineup_model, "LineupSlot", _EmptySlots)

    svc = NotificationService()
    sent: list = []

    async def _capture(**kw):
        sent.append(kw)

    monkeypatch.setattr(svc, "send_push_to_user", _capture)

    _run(svc.notify_player_out(
        player_id="p1", player_name="Joel Embiid", reason="Sidelined",
        nba_date=date(2026, 1, 15),
    ))

    assert [s["user_id"] for s in sent] == ["u1"], (
        "a holder present only in FlutterPlayerSelection must be notified"
    )


def test_out_alert_sends_one_push_per_user_across_leagues(monkeypatch):
    """§4.8 forbids bursts: the same player in three of a user's leagues is
    still one push."""
    from app.modules.notifications.service import NotificationService
    from app.modules.lineups import compat_model, model as lineup_model

    class _Sel:
        user_id = "u1"

    class _ThreeLeagues:
        @staticmethod
        def find(*a, **k):
            class _R:
                async def to_list(self):
                    return [_Sel(), _Sel(), _Sel()]
            return _R()

    class _EmptySlots:
        @staticmethod
        def find(*a, **k):
            class _R:
                async def to_list(self):
                    return []
            return _R()
        player_id = nba_date = score_finalized = None

    monkeypatch.setattr(compat_model, "FlutterPlayerSelection", _ThreeLeagues)
    monkeypatch.setattr(lineup_model, "LineupSlot", _EmptySlots)

    svc = NotificationService()
    sent: list = []

    async def _capture(**kw):
        sent.append(kw)

    monkeypatch.setattr(svc, "send_push_to_user", _capture)

    _run(svc.notify_player_out(
        player_id="p1", player_name="Joel Embiid", reason="Sidelined",
        nba_date=date(2026, 1, 15),
    ))

    assert len(sent) == 1, "one push per user, never one per league"


def test_out_alert_has_a_caller():
    """An alert nothing invokes is the same as no alert at all."""
    from app.modules.players.service import PlayerService

    src = inspect.getsource(PlayerService.set_player_availability)
    assert "notify_player_out" in src


def test_marking_a_player_out_notifies_once_on_the_transition(monkeypatch):
    from app.modules.players.service import PlayerService
    from app.modules.players import service as svc_mod

    calls: list = []

    class _Notif:
        async def notify_player_out(self, **kw):
            calls.append(kw)

    monkeypatch.setattr(
        "app.modules.notifications.service.NotificationService", lambda: _Notif()
    )

    class _Player:
        id = "p1"
        full_name = "Joel Embiid"
        is_out = False
        out_reason = None

        async def save_updated(self, **kw):
            for k, v in kw.items():
                setattr(self, k, v)
            return self

    p = _Player()
    service = PlayerService.__new__(PlayerService)

    changed = _run(service.set_player_availability(p, is_out=True, reason="Sidelined"))
    assert changed is True and p.is_out is True
    assert len(calls) == 1

    # Already OUT: no transition, so no second push.
    changed = _run(service.set_player_availability(p, is_out=True, reason="Sidelined"))
    assert changed is False
    assert len(calls) == 1, "re-reporting the same status must not re-notify"


def test_player_returning_to_in_clears_the_reason_and_sends_nothing(monkeypatch):
    """§4.7: "OUT then re-listed active same night → last known status wins"."""
    from app.modules.players.service import PlayerService

    calls: list = []

    class _Notif:
        async def notify_player_out(self, **kw):
            calls.append(kw)

    monkeypatch.setattr(
        "app.modules.notifications.service.NotificationService", lambda: _Notif()
    )

    class _Player:
        id = "p1"
        full_name = "Joel Embiid"
        is_out = True
        out_reason = "Sidelined"

        async def save_updated(self, **kw):
            for k, v in kw.items():
                setattr(self, k, v)
            return self

    p = _Player()
    service = PlayerService.__new__(PlayerService)

    changed = _run(service.set_player_availability(p, is_out=False))
    assert changed is True
    assert p.is_out is False and p.out_reason is None
    assert calls == [], "coming back IN is not an OUT alert"


# ── §4.8 — one push, private prioritised, never spoiling ──────────────────────

def _duel(is_private: bool, opponent="Marc"):
    class _League:
        type = "private" if is_private else "public"

    class _Match:
        pass

    return DuelContext(
        user_id="u1", league=_League(), match=_Match(), opponent_name=opponent
    )


def test_display_name_falls_back_when_the_opponent_has_no_pseudo():
    assert _display_name(None) == "your opponent"


def test_reminder_names_the_opponent():
    """Spec §4.8 notification 3 — the opponent's name is what creates the
    tension that makes the user open the app."""
    from app.cron.jobs import _send_fcm_reminder

    sent: list = []

    class _Svc:
        async def send_push_to_user(self, **kw):
            sent.append(kw)

    import app.modules.notifications.service as notif_mod
    original = notif_mod.NotificationService
    notif_mod.NotificationService = lambda: _Svc()
    try:
        _run(_send_fcm_reminder("u1", _duel(is_private=True)))
    finally:
        notif_mod.NotificationService = original

    body = sent[0]["body"]
    assert "Marc" in body


def test_results_push_never_reveals_the_outcome():
    """The golden rule: a notification names the stake, never the score or
    the winner — that is what protects the paid live-score feature."""
    from app.cron import jobs

    src = inspect.getsource(jobs._send_results_pushes)
    lowered = src.lower()
    for leak in ("you won", "you lost", "score}", "{score", "winner_name"):
        assert leak not in lowered, f"results push must not reveal '{leak}'"
    assert "is over" in lowered, "it should still name the stake"


def test_results_push_is_keyed_by_user_so_nobody_gets_a_burst():
    """§4.8: "never a burst... if several leagues qualify, send a single
    prioritised push". Keying by user makes a second push impossible."""
    from app.modules.notifications.duel_context import duel_contexts_for_night

    ret = inspect.signature(duel_contexts_for_night).return_annotation
    assert "dict" in str(ret), "must return one context per user, not a list"

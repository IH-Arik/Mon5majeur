"""
Regression tests for the 20/09/2026 infrastructure & security audit fixes.
Every data source is stubbed, so no database is needed.
"""
from __future__ import annotations

import asyncio
from datetime import date, datetime
from types import SimpleNamespace

import pytest

from app.exceptions.errors import BadRequestException, RateLimitException


def _run(coro):
    return asyncio.run(coro)


class _Field:
    """Class-level Beanie field stand-in (cannot be compared without an init)."""

    def __init__(self, name):
        self.name = name

    def __eq__(self, other):  # type: ignore[override]
        return (self.name, other)

    def __lt__(self, other):
        return (self.name, "<", other)

    def __neg__(self):
        return self


# ── 2.1 rate limiter ──────────────────────────────────────────────────────────

class _CounterColl:
    def __init__(self):
        self.docs = {}

    async def find_one_and_update(self, flt, update, upsert=False, return_document=None):
        d = self.docs.setdefault(flt["key"], {"hits": 0})
        d["hits"] += update["$inc"]["hits"]
        return d


@pytest.mark.real_rate_limit
def test_rate_limit_allows_the_limit_then_blocks_with_429(monkeypatch):
    from app.core import rate_limit

    coll = _CounterColl()
    monkeypatch.setattr(
        rate_limit.RateLimitBucket, "get_motor_collection", staticmethod(lambda: coll)
    )
    for _ in range(3):
        _run(rate_limit.hit("login:a@b.c", 3, 60))
    with pytest.raises(RateLimitException) as exc:
        _run(rate_limit.hit("login:a@b.c", 3, 60))
    assert exc.value.status_code == 429
    assert int(exc.value.headers["Retry-After"]) >= 1


@pytest.mark.real_rate_limit
def test_rate_limit_keys_are_independent(monkeypatch):
    from app.core import rate_limit

    coll = _CounterColl()
    monkeypatch.setattr(
        rate_limit.RateLimitBucket, "get_motor_collection", staticmethod(lambda: coll)
    )
    for _ in range(3):
        _run(rate_limit.hit("login:a@b.c", 3, 60))
    _run(rate_limit.hit("login:other@b.c", 3, 60))  # different account: unaffected


def test_client_ip_trusts_x_real_ip_and_ignores_a_spoofed_forwarded_for():
    from app.core.rate_limit import client_ip

    spoofed = SimpleNamespace(
        headers={"x-forwarded-for": "6.6.6.6", "x-real-ip": "203.0.113.9"},
        client=SimpleNamespace(host="10.0.0.1"),
    )
    assert client_ip(spoofed) == "203.0.113.9"

    only_forwarded = SimpleNamespace(
        headers={"x-forwarded-for": "6.6.6.6"}, client=SimpleNamespace(host="10.0.0.1")
    )
    assert client_ip(only_forwarded) == "10.0.0.1", "never trust X-Forwarded-For"


def test_job_lock_fails_open_when_it_cannot_be_used(monkeypatch):
    """The scheduler process may not have the JobLock collection registered;
    the nightly close must still run."""
    from app.cron import lock

    class _Broken:
        @staticmethod
        def get_motor_collection():
            raise RuntimeError("CollectionWasNotInitialized")

    monkeypatch.setattr(lock, "JobLock", _Broken)
    assert _run(lock.try_acquire("daily_close:2026-10-22")) is True
    _run(lock.release("daily_close:2026-10-22"))  # must not raise


def test_job_lock_skips_when_another_process_holds_it(monkeypatch):
    from pymongo.errors import DuplicateKeyError

    from app.cron import lock

    class _Coll:
        async def insert_one(self, doc):
            raise DuplicateKeyError("dup")

    class _Held:
        @staticmethod
        def get_motor_collection():
            return _Coll()

    monkeypatch.setattr(lock, "JobLock", _Held)
    assert _run(lock.try_acquire("daily_close:2026-10-22")) is False


# ── 1.1 idempotent match-day advance ──────────────────────────────────────────

class _LeagueColl:
    """Minimal atomic-guard emulation for the two update styles engine uses."""

    def __init__(self, doc):
        self.doc = doc

    def _matches(self, flt):
        return all(self.doc.get(k) == v for k, v in flt.items() if k != "_id")

    async def update_one(self, flt, upd):
        if not self._matches(flt):
            return SimpleNamespace(modified_count=0)
        self.doc.update(upd["$set"])
        return SimpleNamespace(modified_count=1)

    async def find_one_and_update(self, flt, upd):
        if not self._matches(flt):
            return None
        before = dict(self.doc)
        self.doc.update(upd["$set"])
        return before


def _engine_league(monkeypatch, *, day, total, status="regular_season"):
    from app.modules.leagues import engine

    doc = {"current_match_day": day, "status": status}

    class _StubLeague:
        @staticmethod
        async def get(_id):
            return SimpleNamespace(
                id=_id, status=doc["status"], current_match_day=doc["current_match_day"],
                total_match_days=total,
            )

        @staticmethod
        def get_motor_collection():
            return _LeagueColl(doc)

    monkeypatch.setattr(engine, "League", _StubLeague)
    return engine, doc


def test_advancing_twice_from_the_same_day_moves_only_one_day(monkeypatch):
    engine, doc = _engine_league(monkeypatch, day=3, total=18)
    _run(engine.advance_match_day("L", 3))
    _run(engine.advance_match_day("L", 3))  # a double-fired cron / replay
    assert doc["current_match_day"] == 4


def test_playoffs_are_started_only_once(monkeypatch):
    engine, doc = _engine_league(monkeypatch, day=18, total=18)
    started = []

    async def _start(league):
        started.append(league)

    from app.modules.leagues import playoff_engine

    monkeypatch.setattr(playoff_engine, "start_playoffs", _start)
    _run(engine.advance_match_day("L", 18))
    _run(engine.advance_match_day("L", 18))
    assert doc["status"] == "playoffs"
    assert len(started) == 1


def test_a_league_with_no_duel_on_the_night_is_not_advanced(monkeypatch):
    from app.modules.leagues import engine

    league = SimpleNamespace(id="L", status="regular_season", current_match_day=5)

    class _StubLeague:
        @staticmethod
        def find(_q):
            return SimpleNamespace(to_list=lambda: _async([league]))

    async def _async(v):
        return v

    calls = {"standings": 0, "advance": 0}

    async def _score(*a, **k):
        return 0  # nothing dated this night

    async def _standings(*a, **k):
        calls["standings"] += 1

    async def _advance(*a, **k):
        calls["advance"] += 1

    monkeypatch.setattr(engine, "League", _StubLeague)
    monkeypatch.setattr(engine, "score_match_day", _score)
    monkeypatch.setattr(engine, "update_standings", _standings)
    monkeypatch.setattr(engine, "advance_match_day", _advance)

    _run(engine.run_daily_close(date(2026, 10, 21)))
    assert calls == {"standings": 0, "advance": 0}


# ── 3.1 empty Goalserve response ──────────────────────────────────────────────

def _stub_night(monkeypatch, *, games, stat_rows, sync_calls):
    from app.cron import jobs  # noqa: F401
    from app.modules.players import model as pm
    from app.modules.players import service as ps

    class _NBAGame:
        nba_date = _Field("nba_date")

        @staticmethod
        def find(*_):
            return SimpleNamespace(to_list=lambda: _async(games))

    class _Stats:
        nba_date = _Field("nba_date")

        @staticmethod
        def find(*_):
            return SimpleNamespace(count=lambda: _async(stat_rows))

    async def _async(v):
        return v

    async def _sync(self, night):
        sync_calls.append(night)
        return 0

    async def _finalize(self, game_id):
        return 0

    monkeypatch.setattr(pm, "NBAGame", _NBAGame)
    monkeypatch.setattr(pm, "PlayerGameStats", _Stats)
    monkeypatch.setattr(ps.PlayerService, "sync_scores_for_date", _sync)
    monkeypatch.setattr(ps.PlayerService, "finalize_game_scores", _finalize)


def test_games_but_no_stats_refuses_to_score(monkeypatch):
    from app.cron.jobs import _prepare_night_data
    from app.modules.players.goalserve_client import GoalserveEmptyResponseError

    calls = []
    games = [SimpleNamespace(goalserve_id="g1", status="final")]
    _stub_night(monkeypatch, games=games, stat_rows=0, sync_calls=calls)
    with pytest.raises(GoalserveEmptyResponseError):
        _run(_prepare_night_data(date(2026, 10, 21)))
    assert calls == [date(2026, 10, 21)], "must re-pull the night's scores first"


def test_a_night_with_no_games_is_not_an_error(monkeypatch):
    from app.cron.jobs import _prepare_night_data

    calls = []
    _stub_night(monkeypatch, games=[], stat_rows=0, sync_calls=calls)
    _run(_prepare_night_data(date(2026, 10, 21)))
    assert calls == []


def test_games_with_stats_pass(monkeypatch):
    from app.cron.jobs import _prepare_night_data

    games = [SimpleNamespace(goalserve_id="g1", status="final")]
    _stub_night(monkeypatch, games=games, stat_rows=240, sync_calls=[])
    _run(_prepare_night_data(date(2026, 10, 21)))


# ── 3.3 ESPN roster guard ─────────────────────────────────────────────────────

def test_partial_espn_roster_writes_nothing(monkeypatch):
    from app.modules.players import espn_roster
    from app.modules.players.service import PlayerService

    async def _fetch():
        # 29 teams x 20 players: passes the old "25 teams" guard
        return [{"team_name": f"Team {t}", "full_name": f"P{t}-{i}"} for t in range(29) for i in range(20)]

    monkeypatch.setattr(espn_roster, "fetch_rosters", _fetch)
    svc = PlayerService(repo=None)
    assert _run(svc.sync_from_espn("nba")) == 0


# ── 4.1 / 4.2 leagues ─────────────────────────────────────────────────────────

def _league_service(monkeypatch, *, seats_left=1, active=0):
    from app.modules.leagues import service as ls

    state = {"current_size": 8 - seats_left, "members": []}

    class _Coll:
        async def find_one_and_update(self, flt, upd, return_document=None):
            if "current_size" in flt and isinstance(flt["current_size"], dict):
                cond = flt["current_size"]
                if "$lt" in cond and not state["current_size"] < cond["$lt"]:
                    return None
                if "$gt" in cond and not state["current_size"] > cond["$gt"]:
                    return None
            state["current_size"] += upd["$inc"]["current_size"]
            return {"current_size": state["current_size"]}

    class _StubLeague:
        @staticmethod
        def get_motor_collection():
            return _Coll()

        @staticmethod
        def find(_q):
            return SimpleNamespace(count=lambda: _async(active))

    async def _async(v):
        return v

    class _StubMembership:
        def __init__(self, league_id, user_id):
            self.user_id = user_id

        async def insert(self):
            state["members"].append(self.user_id)

    monkeypatch.setattr(ls, "League", _StubLeague)
    monkeypatch.setattr(ls, "LeagueMembership", _StubMembership)

    async def _no_membership(*_):
        return None

    svc = ls.LeagueService.__new__(ls.LeagueService)
    svc.membership_repo = SimpleNamespace(get_membership=_no_membership)
    return svc, state


def test_only_one_of_two_simultaneous_joins_gets_the_last_seat(monkeypatch):
    svc, state = _league_service(monkeypatch, seats_left=1)
    league = SimpleNamespace(id="L", max_size=8, current_size=7)

    _run(svc._join_with_seat(league, SimpleNamespace(id="u1")))
    with pytest.raises(BadRequestException, match="full"):
        _run(svc._join_with_seat(league, SimpleNamespace(id="u2")))

    assert state["current_size"] == 8
    assert state["members"] == ["u1"]


def test_a_failed_membership_insert_gives_the_seat_back(monkeypatch):
    from app.modules.leagues import service as ls

    svc, state = _league_service(monkeypatch, seats_left=2)

    class _Boom:
        def __init__(self, *a, **k):
            pass

        async def insert(self):
            raise RuntimeError("duplicate key")

    monkeypatch.setattr(ls, "LeagueMembership", _Boom)
    league = SimpleNamespace(id="L", max_size=8, current_size=6)
    with pytest.raises(RuntimeError):
        _run(svc._join_with_seat(league, SimpleNamespace(id="u1")))
    assert state["current_size"] == 6


def test_league_creation_is_capped_at_8_active_leagues(monkeypatch):
    svc, _ = _league_service(monkeypatch, active=7)
    _run(svc._ensure_can_create_league(SimpleNamespace(id="u")))  # 7 -> ok

    svc, _ = _league_service(monkeypatch, active=8)
    with pytest.raises(BadRequestException, match="Maximum 8 active leagues"):
        _run(svc._ensure_can_create_league(SimpleNamespace(id="u")))


# ── 4.3 tokens ────────────────────────────────────────────────────────────────

def _token_service(monkeypatch, balance):
    from app.modules.tokens import service as ts

    state = {"balance": balance, "txs": []}

    class _Coll:
        async def find_one_and_update(self, flt, upd, return_document=None):
            need = flt.get("balance", {}).get("$gte")
            if need is not None and state["balance"] < need:
                return None
            state["balance"] += upd["$inc"]["balance"]
            return {"balance": state["balance"]}

    class _StubWallet:
        @staticmethod
        def get_motor_collection():
            return _Coll()

    class _StubTx:
        def __init__(self, **kw):
            state["txs"].append(kw)

        async def insert(self):
            return None

    monkeypatch.setattr(ts, "TokenWallet", _StubWallet)
    monkeypatch.setattr(ts, "TokenTransaction", _StubTx)

    svc = ts.TokenService()

    async def _wallet(_uid):
        return SimpleNamespace(id="w", balance=state["balance"])

    svc.get_wallet = _wallet
    return svc, state


def test_two_purchases_cannot_both_spend_the_same_tokens(monkeypatch):
    svc, state = _token_service(monkeypatch, balance=150)
    _run(svc.debit("u", 150, tx_type="bonus_activation"))
    with pytest.raises(BadRequestException, match="Insufficient"):
        _run(svc.debit("u", 150, tx_type="bonus_activation"))
    assert state["balance"] == 0, "the balance must never go negative"
    assert len(state["txs"]) == 1


def test_credit_adds_atomically(monkeypatch):
    svc, state = _token_service(monkeypatch, balance=10)
    wallet = _run(svc.credit("u", 5, tx_type="admin_grant"))
    assert wallet.balance == 15 and state["balance"] == 15


def test_failed_bonus_grant_refunds_the_tokens(monkeypatch):
    from app.modules.bonuses import router as br

    events = []

    class _Svc:
        async def debit(self, user_id, cost, **kw):
            events.append(("debit", cost))
            return SimpleNamespace(balance=0)

        async def credit(self, user_id, cost, tx_type, **kw):
            events.append((tx_type, cost))

    async def _cost(_slug):
        return 150

    async def _inv(_user):
        raise RuntimeError("db down")

    monkeypatch.setattr(br, "TokenService", _Svc)
    monkeypatch.setattr(br.bonus_catalog, "get_active_cost", _cost)
    monkeypatch.setattr(br, "_get_inventory", _inv)

    user = SimpleNamespace(id="u")
    with pytest.raises(RuntimeError):
        _run(br.purchase_bonus(SimpleNamespace(bonus="luxury_tax"), user))
    assert events == [("debit", 150), ("refund", 150)]

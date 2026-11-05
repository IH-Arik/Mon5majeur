"""Live screens (duels + Global League) with the substitute: direct rule.

Nothing is replaced until every game of the lineup is final; an opponent's
substitute stays hidden until the first tip-off.
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace

import pytest
from beanie import PydanticObjectId

from app.modules.live_scores import service as lsvc
from tests.unit.modules.test_substitution_live import (
    F, L, NIGHT, S, STARTERS, SUB, TEAMS, _F, oid, row, world,
)

ID = {k: PydanticObjectId(oid(0xA0 + i)) for i, k in enumerate("MLHAXU")}   # real ObjectIds
SIXTH = {"id": oid(77), "name": "Sixth", "position": "SF", "price": "6M"}
ALL = [row(1, 40, 30), row(2, 30, 30), row(3, 20, 30), row(4, 15, 30), row(5, 10, 30)]   # 115
ABSENT_1 = [row(1, 0, 0)] + ALL[1:]
SUB_ROW = [row(99, 22, 25)]


def live_world(monkeypatch, *, status, rows):
    """world() for the substitution rule + the live module's own Player/Stats."""
    world(monkeypatch, status=status, rows=rows)
    by_pid = {str(r.player_id): r for r in rows}

    class Stats:
        player_id = nba_date = _F()

        @staticmethod
        async def find_one(pid, *_):
            r = by_pid.get(str(pid))
            if r is None:
                return None
            return SimpleNamespace(points=0, rebounds=0, assists=0, steals=0, blocks=0, turnovers=0,
                                   minutes_played=r.minutes_played, score_computed=True,
                                   fantasy_score=r.fantasy_score)

    class Players:
        @staticmethod
        async def get(pid):
            return SimpleNamespace(full_name=f"P{int(str(pid), 16)}", position="PG",
                                   team_name=TEAMS.get(int(str(pid), 16)), is_out=False)

    monkeypatch.setattr(lsvc, "PlayerGameStats", Stats)
    monkeypatch.setattr(lsvc, "Player", Players)


def sel(*, substitute=None, sixth=None, chef=False, user="H"):
    return SimpleNamespace(user_id=user, selected_players=STARTERS, substitute_player=substitute,
                           sixth_man_player=sixth, chef_curry=chef)


def lineup(s):
    return asyncio.run(lsvc._live_lineup(s, NIGHT, s.user_id))


# ── a lineup without substitute is unchanged ─────────────────────────────────

def test_no_substitute_same_list_and_total_as_before(monkeypatch):
    live_world(monkeypatch, status=[L, L, L], rows=ALL)
    players, total, substitute, state = lineup(sel())
    assert total == 115 and substitute is None and state is None
    assert [p.slot for p in players] == ["STARTER"] * 5
    assert all(p.is_counted and not p.is_absent for p in players)


def test_no_substitute_sixth_man_still_best_5_of_6(monkeypatch):
    live_world(monkeypatch, status=[L, L, L], rows=ALL + [row(77, 25, 20)])
    players, total, _, _ = lineup(sel(sixth=SIXTH))
    assert total == 130
    assert [p.is_counted for p in players] == [True, True, True, True, False, True]   # #5 (10) dropped


# ── with a substitute: direct rule ───────────────────────────────────────────

def test_everything_final_the_substitute_comes_in(monkeypatch):
    live_world(monkeypatch, status=[F, F, F], rows=ABSENT_1 + SUB_ROW)
    players, total, substitute, state = lineup(sel(substitute=SUB))
    assert total == 22 + 30 + 20 + 15 + 10
    assert len(players) == 5                                   # the substitute is not a 6th item
    assert players[0].is_absent and not players[0].is_counted
    assert substitute.slot == "SUBSTITUTE" and substitute.is_counted and substitute.fantasy_score_live == 22
    assert state == {"status": "entered", "replaced_id": oid(1)}


def test_a_game_still_on_nothing_is_replaced(monkeypatch):
    live_world(monkeypatch, status=[F, L, F], rows=ABSENT_1 + SUB_ROW)
    players, total, substitute, state = lineup(sel(substitute=SUB))
    assert total == 30 + 20 + 15 + 10                          # #1 counts 0, the substitute not yet
    assert not any(p.is_absent for p in players) and all(p.is_counted for p in players)
    assert substitute is not None and not substitute.is_counted
    assert state == {"status": "pending", "replaced_id": None}


def test_game_not_started_nothing_is_replaced(monkeypatch):
    live_world(monkeypatch, status=[S, F, F], rows=ALL[1:] + SUB_ROW)
    _, total, _, state = lineup(sel(substitute=SUB))
    assert state["status"] == "pending" and total == 30 + 20 + 15 + 10


def test_substitute_stays_out_when_everyone_played(monkeypatch):
    live_world(monkeypatch, status=[F, F, F], rows=ALL + SUB_ROW)
    players, total, substitute, state = lineup(sel(substitute=SUB))
    assert total == 115 and not substitute.is_counted and state["status"] == "not_entered"


def test_sixth_man_and_substitute_substitution_first(monkeypatch):
    live_world(monkeypatch, status=[F, F, F], rows=ABSENT_1 + SUB_ROW + [row(77, 25, 20)])
    players, total, substitute, _ = lineup(sel(substitute=SUB, sixth=SIXTH))
    assert total == 112                                         # same as the duel close
    assert [p.is_counted for p in players] == [False, True, True, True, False, True]
    assert substitute.is_counted


def _with_selection(monkeypatch, s):
    async def get_sel(*_):
        return s

    monkeypatch.setattr(lsvc, "_get_selection", get_sel)
    return lsvc._get_live_players_for_user("H", SimpleNamespace(auto_id=1), 1, NIGHT, show_chef_curry=True)


def test_chef_curry_is_added_apart_from_the_substitution(monkeypatch):
    live_world(monkeypatch, status=[F, F, F], rows=ABSENT_1 + SUB_ROW)
    _, total, _, _ = asyncio.run(_with_selection(monkeypatch, sel(substitute=SUB, chef=True)))
    assert total == 97 + 3


# ── get_live_match: the opponent's substitute before tip-off ─────────────────

def live_match(monkeypatch, *, status, rows, started, viewer, match_status="scheduled"):
    live_world(monkeypatch, status=status, rows=rows)
    sels = {ID["H"]: sel(substitute=SUB, user=ID["H"]), ID["A"]: sel(substitute=SUB, user=ID["A"])}
    match = SimpleNamespace(id=ID["M"], league_id=ID["L"], home_user_id=ID["H"], away_user_id=ID["A"],
                            match_day=1, nba_date=NIGHT, status=match_status)
    users = {ID[k]: SimpleNamespace(id=ID[k], team_name=k, jersey_index=0, team_logo="", avatar_url="")
             for k in "HAX"}

    class Matches:
        @staticmethod
        async def get(_):
            return match

    class Leagues:
        @staticmethod
        async def get(_):
            return SimpleNamespace(id=ID["L"], auto_id=1, name="Lg")

    class Users:
        @staticmethod
        async def get(uid):
            return users[uid]

    async def noop(*_):
        return None

    async def get_sel(uid, *_):
        return sels[uid]

    async def showing(*_):
        return True

    async def stale(*_):
        return False

    async def lock(*_):
        return 0 if started else 3600

    import app.modules.leagues.selection_service as ssv

    monkeypatch.setattr(lsvc, "LeagueMatch", Matches)
    monkeypatch.setattr(lsvc, "League", Leagues)
    monkeypatch.setattr(lsvc, "User", Users)
    monkeypatch.setattr(lsvc, "_ensure_premium", noop)
    monkeypatch.setattr(lsvc, "_get_selection", get_sel)
    monkeypatch.setattr(lsvc, "_showing_night", showing)
    monkeypatch.setattr(lsvc, "_is_stale_for_date", stale)
    monkeypatch.setattr(lsvc, "_logo_of", lambda u: "")
    monkeypatch.setattr(ssv, "_lock_in_seconds", lock)
    return asyncio.run(lsvc.LiveScoreService().get_live_match(users[ID[viewer]], ID["M"]))


def test_before_tip_off_the_opponents_substitute_is_hidden_but_my_own_is_shown(monkeypatch):
    out = live_match(monkeypatch, status=[S, S, S], rows=[], started=False, viewer="H")
    assert out.home_substitute is not None and out.home_substitution is not None   # mine
    assert out.away_substitute is None and out.away_substitution is None           # opponent's


def test_after_tip_off_both_substitutes_are_shown(monkeypatch):
    out = live_match(monkeypatch, status=[L, L, L], rows=ALL + SUB_ROW, started=True, viewer="H",
                     match_status="live")
    assert out.home_substitute is not None and out.away_substitute is not None


def test_a_member_viewing_a_third_match_sees_no_substitute_before_tip_off(monkeypatch):
    # viewer is neither side of the duel: nothing of either lineup's substitute
    import app.modules.leagues.model as lm

    class Member:
        league_id = user_id = _F()

        @staticmethod
        async def find_one(*_):
            return SimpleNamespace()

    monkeypatch.setattr(lm, "LeagueMembership", Member)
    out = live_match(monkeypatch, status=[S, S, S], rows=[], started=False, viewer="X")
    assert out.home_substitute is None and out.away_substitute is None


# ── Global League live ───────────────────────────────────────────────────────

def _global_live(monkeypatch, *, status, rows, substitute):
    live_world(monkeypatch, status=status, rows=rows)
    me = SimpleNamespace(id=ID["U"])

    class Leagues:
        type = _F()

        @staticmethod
        async def find_one(*_):
            return SimpleNamespace(id=ID["L"], auto_id=1, name="Global", current_match_day=1)

    class Sels:
        user_id = league_auto_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return sel(substitute=substitute, user=ID["U"])

    async def live_night():
        return NIGHT

    async def today():
        return NIGHT

    async def ok(*_):
        return None

    async def showing(*_):
        return True

    async def stale(*_):
        return False

    import app.modules.lineups.compat_model as cm
    import app.modules.players.compat_router as cr
    import app.modules.players.nba_night as nn

    monkeypatch.setattr(lsvc, "League", Leagues)
    monkeypatch.setattr(cm, "FlutterPlayerSelection", Sels)
    monkeypatch.setattr(nn, "live_night", live_night)
    monkeypatch.setattr(cr, "_nba_today", today)
    monkeypatch.setattr(lsvc, "_ensure_premium", ok)
    monkeypatch.setattr(lsvc, "_showing_night", showing)
    monkeypatch.setattr(lsvc, "_is_stale_for_date", stale)
    return asyncio.run(lsvc.LiveScoreService().get_global_live(me))


def test_global_live_uses_the_direct_rule(monkeypatch):
    out = _global_live(monkeypatch, status=[F, F, F], rows=ABSENT_1 + SUB_ROW, substitute=SUB)
    assert out.total_score == 97
    assert out.substitution == {"status": "entered", "replaced_id": oid(1)}
    assert out.substitute.fantasy_score_live == 22 and len(out.players) == 5


def test_global_live_flags_a_starter_with_no_minute_even_without_a_substitute(monkeypatch):
    out = _global_live(monkeypatch, status=[F, L, L], rows=ABSENT_1[1:], substitute=None)   # #1: game final, no row
    assert [p.is_absent for p in out.players] == [True, False, False, False, False]
    assert out.substitute is None and out.substitution is None


def test_live_duel_flags_a_starter_with_no_minute_too(monkeypatch):
    out = live_match(monkeypatch, status=[F, L, L], rows=ALL[1:], started=True, viewer="H",
                     match_status="live")
    assert [p.is_absent for p in out.home_players][:1] == [True]
    assert not any(p.is_absent for p in out.home_players[1:])

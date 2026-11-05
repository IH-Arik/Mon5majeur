"""A starter who played no minute is flagged "absent" (OUT on the screens), with
or without a substitute. Only minutes decide, never points."""
from __future__ import annotations

import asyncio
from types import SimpleNamespace

from app.modules.leagues import global_router as gr
from app.modules.leagues import substitution_service as ss
from tests.unit.modules.test_substitution_live import (
    F, L, NIGHT, S, STARTERS, SUB, _F, _global, _sel, oid, row, world,
)
from tests.unit.modules.test_substitution_live_scores import ALL, live_world, sel as live_sel
from app.modules.live_scores import service as lsvc

ABSENT_1 = [row(1, 0, 0)] + ALL[1:]                      # #1: row at 0 minute
NO_ROW_1 = ALL[1:]                                       # #1: no stats row at all
PLAYED_ZERO_POINTS = [row(1, 0, 30)] + ALL[1:]           # #1 played 30 minutes and scored 0


def flagged(items):
    return [i["id"] for i in items if i.get("absent")]


def items_of(*, closing, lineup=None):
    items = [dict(p) for p in (lineup or STARTERS)]
    asyncio.run(ss.mark_did_not_play(items, NIGHT, closing=closing))
    return items


# ── at the close ─────────────────────────────────────────────────────────────

def test_close_row_at_zero_minute_is_out(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=ABSENT_1)
    assert flagged(items_of(closing=True)) == [oid(1)]


def test_close_no_row_at_all_is_out(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=NO_ROW_1)
    assert flagged(items_of(closing=True)) == [oid(1)]


def test_close_played_and_scored_zero_is_not_out(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=PLAYED_ZERO_POINTS)
    assert flagged(items_of(closing=True)) == []


def test_close_everybody_played_nobody_is_out(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=ALL)
    assert flagged(items_of(closing=True)) == []


def test_sixth_man_is_never_flagged(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=ALL[1:])
    sixth = {"id": oid(7), "name": "P7", "position": "PG", "is_sixth_man": True}   # no stats row at all
    items = items_of(closing=True, lineup=[STARTERS[0], sixth])
    assert flagged(items) == [oid(1)]


# ── while the games are on ───────────────────────────────────────────────────

def test_live_game_final_without_minute_is_out(monkeypatch):
    world(monkeypatch, status=[F, L, L], rows=NO_ROW_1)
    assert flagged(items_of(closing=False)) == [oid(1)]


def test_live_game_not_over_is_not_out(monkeypatch):
    for status in (S, L):
        world(monkeypatch, status=[status, F, F], rows=NO_ROW_1)
        assert flagged(items_of(closing=False)) == [], status


def test_live_zero_minute_row_in_a_game_in_progress_is_not_out(monkeypatch):
    world(monkeypatch, status=[L, F, F], rows=ABSENT_1)
    assert flagged(items_of(closing=False)) == []


# ── the screens' payloads ────────────────────────────────────────────────────

def test_global_items_flag_the_out_starter_without_any_substitute(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=ABSENT_1)
    _global(monkeypatch, _sel(None))
    items, sub, state = asyncio.run(gr._global_selection_items("U", 1, 1, NIGHT, True))
    assert sub is None and state is None
    assert flagged(items) == [oid(1)]


def test_live_global_flags_the_out_starter_without_any_substitute(monkeypatch):
    live_world(monkeypatch, status=[F, L, L], rows=NO_ROW_1)
    players, *_ = asyncio.run(lsvc._live_lineup(live_sel(), NIGHT, "H", flag_did_not_play=True))
    assert [p.is_absent for p in players] == [True, False, False, False, False]


def test_live_lineup_without_the_flag_keeps_its_old_look(monkeypatch):
    live_world(monkeypatch, status=[F, F, F], rows=NO_ROW_1)
    players, *_ = asyncio.run(lsvc._live_lineup(live_sel(), NIGHT, "H"))
    assert not any(p.is_absent for p in players)



def _published(monkeypatch, sel):
    class Daily:
        user_id = league_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return SimpleNamespace(total_points=97)

    class Sel:
        user_id = league_auto_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return sel

    monkeypatch.setattr(gr, "GlobalLeagueDailyScore", Daily)
    monkeypatch.setattr(gr, "FlutterPlayerSelection", Sel)
    gr.clear_result_cache()
    return asyncio.run(gr._night_payload(SimpleNamespace(id="L", auto_id=1), SimpleNamespace(id="U"), NIGHT))


def test_published_night_flags_the_out_starter_without_any_substitute(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=ABSENT_1)
    out = _published(monkeypatch, _sel(None))
    assert "substitute" not in out and "substitution" not in out      # no substitute, same shape as before
    assert [i.get("absent") for i in out["selection"]] == [True, None, None, None, None]


def test_published_night_postponed_game_without_row_is_out_at_the_close(monkeypatch):
    world(monkeypatch, status=[S, F, F], rows=NO_ROW_1)
    out = _published(monkeypatch, _sel(None))
    assert flagged(out["selection"]) == [oid(1)]


def test_published_night_played_and_scored_zero_is_not_out(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=PLAYED_ZERO_POINTS)
    out = _published(monkeypatch, _sel(None))
    assert flagged(out["selection"]) == []


def test_voir_l_equipe_endpoint_flags_the_out_starter_without_any_substitute(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=ABSENT_1)

    async def league():
        return SimpleNamespace(id="L", auto_id=1)

    class Users:
        auto_id = _F()

        @staticmethod
        async def find_one(*_):
            return SimpleNamespace(id="U", team_name="Local r1", email="r1@example.com")

    class _Neg(_F):
        def __neg__(self):
            return 0

    class Daily:
        user_id = league_id = _F()
        nba_date = _Neg()

        @staticmethod
        def find(*_):
            async def first():
                return SimpleNamespace(nba_date=NIGHT, total_points=97)

            return SimpleNamespace(sort=lambda *_: SimpleNamespace(first_or_none=first))

    class Sel:
        user_id = league_auto_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return _sel(None)

    async def enrich(players, for_date=None):
        return [dict(p, score=0) for p in players]

    monkeypatch.setattr(gr, "_get_global_league", league)
    monkeypatch.setattr(gr, "User", Users)
    monkeypatch.setattr(gr, "GlobalLeagueDailyScore", Daily)
    monkeypatch.setattr(gr, "FlutterPlayerSelection", Sel)
    monkeypatch.setattr(gr, "_enrich_with_scores", enrich)
    out = asyncio.run(gr.get_global_leaderboard_team_detail(7, None))
    assert flagged(out.selected_players) == [oid(1)]

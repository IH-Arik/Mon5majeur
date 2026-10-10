"""QA #10 12: a ranking is computed once per publication."""
from __future__ import annotations

import asyncio
from datetime import date

from app.modules.leagues import global_router as gr


def _setup(monkeypatch, token):
    calls = {"n": 0}

    async def _league():
        return object()

    async def _today():
        return date(2026, 10, 8)

    async def _tok(_league):
        return token["v"]

    async def _compute(league, period, offset, today):
        calls["n"] += 1
        return f"ranking-{calls['n']}"

    monkeypatch.setattr(gr, "_get_global_league", _league)
    monkeypatch.setattr(gr, "_nba_today", _today)
    monkeypatch.setattr(gr, "_leaderboard_token", _tok)
    monkeypatch.setattr(gr, "_compute_leaderboard", _compute)
    gr.clear_leaderboard_cache()
    return calls


def _ask(period="weekly", offset=0):
    return asyncio.run(gr.get_global_leaderboard(period=period, offset=offset, current_user=None))


def test_same_ranking_is_served_from_cache(monkeypatch):
    calls = _setup(monkeypatch, {"v": "2026-10-07"})
    assert _ask() == _ask() == "ranking-1"
    assert calls["n"] == 1


def test_weekly_and_monthly_are_separate_entries(monkeypatch):
    calls = _setup(monkeypatch, {"v": "2026-10-07"})
    _ask("weekly"), _ask("monthly"), _ask("weekly"), _ask("monthly")
    assert calls["n"] == 2


def test_a_new_publication_recomputes(monkeypatch):
    token = {"v": "2026-10-07"}
    calls = _setup(monkeypatch, token)
    _ask()
    token["v"] = "2026-10-08"       # a new night was archived at 09:00
    assert _ask() == "ranking-2"
    assert calls["n"] == 2


def test_deleting_an_account_clears_the_rankings(monkeypatch):
    calls = _setup(monkeypatch, {"v": "2026-10-07"})
    _ask()
    gr.clear_leaderboard_cache()
    _ask()
    assert calls["n"] == 2

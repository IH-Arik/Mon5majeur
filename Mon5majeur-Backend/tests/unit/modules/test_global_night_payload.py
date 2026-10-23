"""QA #10 2 / 14: a Global night's score is that night's own, 0 without a lineup."""
from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

from app.modules.leagues import global_router as gr


class _F:
    def __eq__(self, other):
        return other


def _stub(monkeypatch, *, score, sel, stats):
    calls = {"stats": 0}

    class _Score:
        user_id = league_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return score

    class _Sel:
        user_id = league_auto_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return sel

    class _Stats:
        @staticmethod
        def find(_query):
            calls["stats"] += 1

            async def _list():
                return stats

            return SimpleNamespace(to_list=_list)

    monkeypatch.setattr(gr, "GlobalLeagueDailyScore", _Score)
    monkeypatch.setattr(gr, "FlutterPlayerSelection", _Sel)
    monkeypatch.setattr(gr, "PlayerGameStats", _Stats)
    gr.clear_result_cache()
    return calls


LEAGUE = SimpleNamespace(id="L", auto_id=1)
USER = SimpleNamespace(id="U")
NIGHT = date(2026, 10, 6)


def test_no_lineup_that_night_is_zero_points_not_a_weekly_total(monkeypatch):
    # a weekly total (55) exists elsewhere; this night has no lineup
    _stub(monkeypatch, score=SimpleNamespace(total_points=55), sel=None, stats=[])
    out = asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert out["no_lineup"] is True and out["total_points"] == 0 and out["selection"] == []


def test_points_and_players_of_the_night(monkeypatch):
    pid = "6" * 24
    sel = SimpleNamespace(selected_players=[{"id": pid, "name": "A", "position": "PG"}])
    from beanie import PydanticObjectId

    stat = SimpleNamespace(
        player_id=PydanticObjectId(pid), fantasy_score=22.4, score_computed=True
    )
    calls = _stub(monkeypatch, score=SimpleNamespace(total_points=22.4), sel=sel, stats=[stat])
    out = asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert out["no_lineup"] is False
    assert out["total_points"] == 22
    assert out["selection"][0]["score"] == 22
    assert calls["stats"] == 1                      # one query for the whole lineup


def _one_player(monkeypatch, *, computed, total=8):
    from beanie import PydanticObjectId

    pid = "6" * 24
    sel = SimpleNamespace(selected_players=[{"id": pid, "name": "A", "position": "PG"}])
    stat = SimpleNamespace(
        player_id=PydanticObjectId(pid), fantasy_score=8, score_computed=computed
    )
    return _stub(monkeypatch, score=SimpleNamespace(total_points=total), sel=sel, stats=[stat])


def test_player_points_match_the_ranking_even_while_score_computed_is_false(monkeypatch):
    # a box-score sync flips score_computed to False; the ranking still counts
    # fantasy_score, so the lineup screen must show the same points
    _one_player(monkeypatch, computed=False)
    out = asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert out["selection"][0]["score"] == 8
    assert sum(p["score"] for p in out["selection"]) == out["total_points"]


def test_a_closed_settled_night_is_cached(monkeypatch):
    _one_player(monkeypatch, computed=True)
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert (str(USER.id), NIGHT.isoformat()) in gr._RESULT_CACHE


def test_a_night_with_unsettled_stats_is_not_cached(monkeypatch):
    _one_player(monkeypatch, computed=False)
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert not gr._RESULT_CACHE


def test_a_night_not_closed_yet_is_not_cached(monkeypatch):
    _one_player(monkeypatch, computed=True)
    monkeypatch.setattr(gr, "_night_closed", lambda night, now=None: False)
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert not gr._RESULT_CACHE


def test_cached_entry_expires_after_the_ttl(monkeypatch):
    calls = _one_player(monkeypatch, computed=True)
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert calls["stats"] == 1                      # second call served from cache
    key = (str(USER.id), NIGHT.isoformat())
    stored, payload = gr._RESULT_CACHE[key]
    gr._RESULT_CACHE[key] = (stored - gr._RESULT_CACHE_TTL - 1, payload)
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert calls["stats"] == 2


def test_close_is_09h_paris_the_day_after_the_night():
    night = date(2026, 10, 22)  # Paris is UTC+2 that day: 09:00 Paris = 07:00 UTC
    assert not gr._night_closed(night, datetime(2026, 10, 23, 6, 59, tzinfo=timezone.utc))
    assert gr._night_closed(night, datetime(2026, 10, 23, 7, 0, tzinfo=timezone.utc))

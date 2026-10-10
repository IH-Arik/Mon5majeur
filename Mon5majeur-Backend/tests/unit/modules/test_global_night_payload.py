"""QA #10 2 / 14: a Global night's score is that night's own, 0 without a lineup."""
from __future__ import annotations

import asyncio
from datetime import date, datetime
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

    stat = SimpleNamespace(player_id=PydanticObjectId(pid), fantasy_score=22.4)
    calls = _stub(monkeypatch, score=SimpleNamespace(total_points=22.4), sel=sel, stats=[stat])
    out = asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert out["no_lineup"] is False
    assert out["total_points"] == 22
    assert out["selection"][0]["score"] == 22
    assert calls["stats"] == 1                      # one query for the whole lineup


def test_a_published_night_is_cached(monkeypatch):
    sel = SimpleNamespace(selected_players=[])
    calls = _stub(monkeypatch, score=SimpleNamespace(total_points=0), sel=sel, stats=[])
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    asyncio.run(gr._night_payload(LEAGUE, USER, NIGHT))
    assert calls["stats"] == 1 or calls["stats"] == 0
    assert (str(USER.id), NIGHT.isoformat()) in gr._RESULT_CACHE

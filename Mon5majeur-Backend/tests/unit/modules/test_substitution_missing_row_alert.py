"""Close-time trace: a substitution that rests on the ABSENCE of a stats row."""
from __future__ import annotations

import asyncio
import logging
from types import SimpleNamespace

from beanie import PydanticObjectId

from app.modules.leagues import substitution_service as ss
from tests.unit.modules.test_substitution_live import (
    F, L, NIGHT, S, STARTERS, SUB, TEAMS, oid, row, world,
)

MARKER = "missing stats row"
PLAYED = [row(2, 30, 30), row(3, 20, 30), row(4, 15, 30), row(5, 10, 30), row(99, 22, 25)]
MATES = [row(201, 12, 20), row(202, 8, 15)]            # two Lakers teammates of starter #1 with rows


def setup(monkeypatch, *, status, rows):
    world(monkeypatch, status=status, rows=rows)
    teams = {**TEAMS, 201: "Los Angeles Lakers", 202: "Los Angeles Lakers"}
    people = [SimpleNamespace(id=PydanticObjectId(oid(n)), full_name=f"P{n}", team_name=t,
                              team_goalserve_id=t[:3].upper()) for n, t in teams.items()]

    class Players:
        @staticmethod
        async def get(pid):
            return next((p for p in people if p.id == pid), None)

        @staticmethod
        def find(query):
            if "_id" in query:
                wanted = {str(x) for x in query["_id"]["$in"]}
                found = [p for p in people if str(p.id) in wanted]
            else:
                found = [p for p in people if p.team_name == query["team_name"]]

            async def to_list():
                return found

            return SimpleNamespace(to_list=to_list)

    monkeypatch.setattr(ss, "Player", Players)


def close(**kw):
    return asyncio.run(ss.resolve_substitution(STARTERS, SUB, NIGHT, closing=True, user_id="U-42", **kw))


def alerts(caplog):
    return [r.getMessage() for r in caplog.records if MARKER in r.getMessage()]


def test_missing_row_with_a_final_game_leaves_a_trace(monkeypatch, caplog):
    setup(monkeypatch, status=[F, F, F], rows=PLAYED + MATES)        # starter #1 has NO row
    with caplog.at_level(logging.WARNING, logger=ss.logger.name):
        assert close().entered
    (msg,) = alerts(caplog)
    assert "user=U-42" in msg and f"night={NIGHT}" in msg
    assert f"starter={oid(1)} (P1)" in msg and "team=Los Angeles Lakers" in msg
    assert "team_stat_rows=2" in msg


def test_a_whole_team_without_rows_stands_out(monkeypatch, caplog):
    setup(monkeypatch, status=[F, F, F], rows=PLAYED)                # nobody of the Lakers has a row
    with caplog.at_level(logging.WARNING, logger=ss.logger.name):
        close()
    (msg,) = alerts(caplog)
    assert "team_stat_rows=0" in msg


def test_a_row_at_zero_minute_is_the_normal_case_no_trace(monkeypatch, caplog):
    setup(monkeypatch, status=[F, F, F], rows=[row(1, 0, 0)] + PLAYED + MATES)
    with caplog.at_level(logging.WARNING, logger=ss.logger.name):
        assert close().entered
    assert alerts(caplog) == []


def test_unfinished_game_has_its_own_trace_not_this_one(monkeypatch, caplog):
    setup(monkeypatch, status=[S, F, F], rows=PLAYED + MATES)        # starter #1's game is not final
    with caplog.at_level(logging.WARNING, logger=ss.logger.name):
        assert close().entered
    assert alerts(caplog) == []
    assert any("not final" in r.getMessage() for r in caplog.records)


def test_no_trace_when_the_substitute_does_not_enter(monkeypatch, caplog):
    setup(monkeypatch, status=[F, F, F], rows=[row(1, 40, 30)] + PLAYED + MATES)
    with caplog.at_level(logging.WARNING, logger=ss.logger.name):
        assert not close().entered
    assert caplog.records == []


def test_no_trace_in_live_mode(monkeypatch, caplog):
    setup(monkeypatch, status=[F, F, F], rows=PLAYED + MATES)
    with caplog.at_level(logging.WARNING, logger=ss.logger.name):
        asyncio.run(ss.resolve_substitution(STARTERS, SUB, NIGHT, closing=False))
    assert alerts(caplog) == []


def test_a_failing_trace_never_breaks_the_close(monkeypatch, caplog):
    setup(monkeypatch, status=[F, F, F], rows=PLAYED + MATES)

    class Broken:
        @staticmethod
        async def get(_):
            raise RuntimeError("database down")

        find = staticmethod(ss.Player.find)

    monkeypatch.setattr(ss, "Player", Broken)
    with caplog.at_level(logging.WARNING, logger=ss.logger.name):
        assert close().entered                                       # the substitution still applies
    assert alerts(caplog) == []

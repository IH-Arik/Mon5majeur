"""Substitute in the duels (09:00 close): score_full_selection / score_match_day.

Order of the rules: substitution first, then 6th Man "best 5 of 6", then Chef
Curry +3 (a bonus of the match, never of a player).
"""
from __future__ import annotations

import asyncio
import logging
from types import SimpleNamespace

import pytest

from app.modules.leagues import engine
from app.modules.leagues import selection_service as sel_svc
from app.modules.leagues.substitution_service import logger as ss_logger
from tests.unit.modules.test_substitution_live import (
    F, GAMES, L, NIGHT, S, STARTERS, SUB, _F, oid, person, row, world,
)

SIXTH = {"id": oid(77), "name": "Sixth", "position": "SF", "price": "6M"}


@pytest.fixture(autouse=True)
def _models(monkeypatch):
    """_score_one_player imports PlayerGameStats from the model module at call time."""
    import app.modules.players.model as pm

    def use(stub):
        monkeypatch.setattr(pm, "PlayerGameStats", stub)

    return use


def setup_world(monkeypatch, _models, *, status, rows):
    from app.modules.leagues import substitution_service as ss

    world(monkeypatch, status=status, rows=rows)
    _models(ss.PlayerGameStats)          # same stat stub everywhere


def sel(*, substitute=None, sixth=None, chef=False, user="U"):
    return SimpleNamespace(
        user_id=user, selected_players=STARTERS, substitute_player=substitute,
        sixth_man_player=sixth, chef_curry=chef,
    )


def score(s):
    return asyncio.run(sel_svc.score_full_selection(s, NIGHT))


def old_score(s, scores_by_id):
    """score_full_selection exactly as it was before the substitute existed."""
    scores = [scores_by_id.get(p["id"], 0.0) for p in s.selected_players]
    if s.sixth_man_player is not None:
        scores.append(scores_by_id.get(s.sixth_man_player["id"], 0.0))
        scores = sorted(scores, reverse=True)[:5]
    total = sum(scores)
    if s.chef_curry:
        total += 3
    return round(total, 2)


ALL = [row(1, 40, 30), row(2, 30, 30), row(3, 20, 30), row(4, 15, 30), row(5, 10, 30)]   # 115
ABSENT_1 = [row(1, 0, 0)] + ALL[1:]                                                       # #1 (15M) out
SUB_ROW = [row(99, 22, 25)]


# ── a lineup without a substitute scores exactly as before ───────────────────

@pytest.mark.parametrize("chef", [False, True])
@pytest.mark.parametrize("sixth_score", [None, 25, 5])
def test_no_substitute_gives_exactly_the_old_score(monkeypatch, _models, chef, sixth_score):
    rows = list(ALL) + ([row(77, sixth_score, 20)] if sixth_score is not None else [])
    setup_world(monkeypatch, _models, status=[F, F, F], rows=rows)
    s = sel(sixth=SIXTH if sixth_score is not None else None, chef=chef)
    by_id = {str(r.player_id): r.fantasy_score for r in rows}
    assert score(s) == old_score(s, by_id)


def test_no_substitute_known_values(monkeypatch, _models):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ALL + [row(77, 25, 20)])
    assert score(sel()) == 115
    assert score(sel(chef=True)) == 118
    assert score(sel(sixth=SIXTH)) == 130          # best 5 of [40,30,25,20,15,10]
    assert score(sel(sixth=SIXTH, chef=True)) == 133


# ── with a substitute ────────────────────────────────────────────────────────

@pytest.mark.parametrize("chef,expected", [(False, 97), (True, 100)])
def test_absent_starter_replaced_with_and_without_chef_curry(monkeypatch, _models, chef, expected):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + SUB_ROW)
    assert score(sel(substitute=SUB, chef=chef)) == expected    # 22+30+20+15+10 (+3)


@pytest.mark.parametrize("chef,expected", [(False, 115), (True, 118)])
def test_substitute_who_does_not_enter_changes_nothing(monkeypatch, _models, chef, expected):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ALL + SUB_ROW)
    assert score(sel(substitute=SUB, chef=chef)) == expected


def test_chef_curry_is_the_same_plus_three_whoever_played(monkeypatch, _models):
    for rows in (ALL + SUB_ROW, ABSENT_1 + SUB_ROW):
        setup_world(monkeypatch, _models, status=[F, F, F], rows=rows)
        assert score(sel(substitute=SUB, chef=True)) == score(sel(substitute=SUB)) + 3


def test_substitute_absent_himself_still_enters_for_zero(monkeypatch, _models):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + [row(99, 0, 0)])
    assert score(sel(substitute=SUB)) == 30 + 20 + 15 + 10


# ── 6th Man + substitute: substitution first, then best 5 of 6 ───────────────

def test_sixth_man_and_substitute_substitution_first(monkeypatch, _models):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + SUB_ROW + [row(77, 25, 20)])
    # counted starters [22,30,20,15,10] + sixth man 25 -> best 5 = 30+25+22+20+15
    assert score(sel(substitute=SUB, sixth=SIXTH)) == 112
    # the other order (best 5 of 6 with the absent 0, then substitution) would give 100
    assert score(sel(substitute=SUB, sixth=SIXTH)) != 100


def test_sixth_man_low_score_is_dropped_after_substitution(monkeypatch, _models):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + SUB_ROW + [row(77, 5, 20)])
    assert score(sel(substitute=SUB, sixth=SIXTH)) == 97


def test_sixth_man_substitute_and_chef_curry(monkeypatch, _models):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + SUB_ROW + [row(77, 25, 20)])
    assert score(sel(substitute=SUB, sixth=SIXTH, chef=True)) == 115


# ── the 09:00 duel close, end to end ─────────────────────────────────────────

def _close(monkeypatch, _models, rows, home_sel, away_sel):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=rows)
    match = SimpleNamespace(home_user_id="H", away_user_id="A", status="scheduled",
                            home_score=None, away_score=None, winner_id=None)

    async def save():
        return None

    match.save = save
    sels = {"H": home_sel, "A": away_sel}

    class Match:
        league_id = match_day = nba_date = _F()

        @staticmethod
        def find(*_):
            async def to_list():
                return [match]

            return SimpleNamespace(to_list=to_list)

    class League:
        @staticmethod
        async def get(_):
            return SimpleNamespace(id="L", auto_id=1)

    class Sel:
        user_id = league_auto_id = match_day = _F()

        @staticmethod
        async def find_one(uid, *_):
            return sels[uid]

    import app.modules.lineups.compat_model as cm

    monkeypatch.setattr(engine, "League", League)
    monkeypatch.setattr(engine, "LeagueMatch", Match)
    monkeypatch.setattr(cm, "FlutterPlayerSelection", Sel)
    asyncio.run(engine.score_match_day("L", 1, NIGHT))
    return match


def test_duel_is_decided_with_the_substitution(monkeypatch, _models):
    # home: 97 only thanks to the substitute; away: plain 96
    rows = ABSENT_1 + SUB_ROW
    away = sel(user="A")
    away.selected_players = [person(n) for n in (1, 2, 3, 4, 5)]
    match = _close(monkeypatch, _models, rows, sel(substitute=SUB, user="H"), away)
    # away has the same five players (same stats): 0+30+20+15+10 = 75, home 97
    assert (match.home_score, match.away_score) == (97, 75) and match.winner_id == "H"


def test_duel_without_substitute_is_unchanged(monkeypatch, _models):
    match = _close(monkeypatch, _models, ABSENT_1 + SUB_ROW, sel(user="H"), sel(user="A"))
    assert (match.home_score, match.away_score) == (75, 75)
    assert match.winner_id == "H"            # tie: home wins, as before


# ── log trace when the decision rests on an unfinished game ──────────────────

def test_warning_when_the_replaced_starters_game_is_not_final(monkeypatch, _models, caplog):
    # #1's game was postponed (still "scheduled", no row): replaced at close, with a trace
    setup_world(monkeypatch, _models, status=[S, F, F], rows=ALL[1:] + SUB_ROW)
    with caplog.at_level(logging.WARNING, logger=ss_logger.name):
        assert score(sel(substitute=SUB, user="U-42")) == 97
    msg = " ".join(r.getMessage() for r in caplog.records if r.levelno == logging.WARNING)
    assert "user=U-42" in msg and f"night={NIGHT}" in msg
    assert f"replaced={oid(1)}" in msg and f"substitute={oid(99)}" in msg
    assert "game=scheduled" in msg


def test_warning_when_the_game_is_stuck_live(monkeypatch, _models, caplog):
    setup_world(monkeypatch, _models, status=[L, F, F], rows=ABSENT_1 + SUB_ROW)
    with caplog.at_level(logging.WARNING, logger=ss_logger.name):
        score(sel(substitute=SUB))
    assert any("game=live" in r.getMessage() for r in caplog.records)


def test_warning_when_the_substitutes_game_is_not_final(monkeypatch, _models, caplog):
    setup_world(monkeypatch, _models, status=[F, F, L], rows=ABSENT_1 + SUB_ROW)   # sub plays game 3
    with caplog.at_level(logging.WARNING, logger=ss_logger.name):
        score(sel(substitute=SUB))
    assert any("game=live" in r.getMessage() for r in caplog.records)


def test_no_warning_when_every_game_is_final(monkeypatch, _models, caplog):
    setup_world(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + SUB_ROW)
    with caplog.at_level(logging.WARNING, logger=ss_logger.name):
        score(sel(substitute=SUB))
    assert not caplog.records


def test_no_warning_when_the_substitute_does_not_enter(monkeypatch, _models, caplog):
    setup_world(monkeypatch, _models, status=[S, F, F], rows=ALL + SUB_ROW)
    with caplog.at_level(logging.WARNING, logger=ss_logger.name):
        score(sel(substitute=SUB))
    assert not caplog.records


def test_no_warning_in_live_mode(monkeypatch, _models, caplog):
    from app.modules.leagues import substitution_service as ss

    setup_world(monkeypatch, _models, status=[S, F, F], rows=ALL[1:] + SUB_ROW)
    with caplog.at_level(logging.WARNING, logger=ss_logger.name):
        asyncio.run(ss.resolve_substitution(STARTERS, SUB, NIGHT, closing=False))
    assert not caplog.records


def test_a_failing_trace_never_breaks_the_close(monkeypatch, _models):
    from app.modules.leagues import substitution_service as ss

    setup_world(monkeypatch, _models, status=[S, F, F], rows=ALL[1:] + SUB_ROW)

    async def boom(*_):
        raise RuntimeError("database down")

    monkeypatch.setattr(ss, "_game_statuses", boom)
    assert score(sel(substitute=SUB)) == 97          # the substitution still applies

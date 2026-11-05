"""Substitute on the duel Result page (get_match_result / total_from_scores).

The page and the 09:00 duel close must give the very same total for a lineup.
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace

import pytest

from app.modules.leagues import selection_service as sel_svc
from app.modules.leagues import substitution_service as ss
from tests.unit.modules.test_substitution_live import (
    F, L, NIGHT, S, STARTERS, SUB, _F, oid, row, world,
)

SIXTH = {"id": oid(77), "name": "Sixth", "position": "SF", "price": "6M"}
ALL = [row(1, 40, 30), row(2, 30, 30), row(3, 20, 30), row(4, 15, 30), row(5, 10, 30)]   # 115
ABSENT_1 = [row(1, 0, 0)] + ALL[1:]
SUB_ROW = [row(99, 22, 25)]


@pytest.fixture(autouse=True)
def _models(monkeypatch):
    import app.modules.players.model as pm

    def use(stub):
        monkeypatch.setattr(pm, "PlayerGameStats", stub)

    return use


def setup(monkeypatch, _models, *, status, rows):
    world(monkeypatch, status=status, rows=rows)
    _models(ss.PlayerGameStats)


def sel(*, substitute=None, sixth=None, chef=False, user="H"):
    return SimpleNamespace(
        user_id=user, selected_players=STARTERS, substitute_player=substitute,
        sixth_man_player=sixth, chef_curry=chef, luxury_tax=False,
    )


def by_id(rows):
    return {str(r.player_id): r.fantasy_score for r in rows}


# ── no substitute: strictly the old function ─────────────────────────────────

def old_total_from_scores(sel, scores_by_player, with_chef_curry=True):
    """total_from_scores exactly as it was before the substitute existed."""
    def one(p):
        return scores_by_player.get(str(p.get("id", "")), 0.0)

    scores = [one(p) for p in sel.selected_players]
    if sel.sixth_man_player is not None:
        scores.append(one(sel.sixth_man_player))
        scores = sorted(scores, reverse=True)[:5]
    total = sum(scores)
    if sel.chef_curry and with_chef_curry:
        total += 3
    return round(total, 2)


@pytest.mark.parametrize("chef", [False, True])
@pytest.mark.parametrize("with_chef", [False, True])
@pytest.mark.parametrize("sixth", [None, 25, 5])
def test_lineup_without_substitute_is_strictly_identical(chef, with_chef, sixth):
    rows = ALL + ([row(77, sixth, 20)] if sixth is not None else [])
    s = sel(sixth=SIXTH if sixth is not None else None, chef=chef)
    scores = by_id(rows)
    assert sel_svc.total_from_scores(s, scores, with_chef_curry=with_chef) == \
        old_total_from_scores(s, scores, with_chef_curry=with_chef)


# ── page total == duel close total, with a substitute ────────────────────────

SCENARIOS = {
    "entered": ABSENT_1 + SUB_ROW,
    "not_entered": ALL + SUB_ROW,
    "substitute_absent": ABSENT_1 + [row(99, 0, 0)],
}


@pytest.mark.parametrize("chef", [False, True])
@pytest.mark.parametrize("sixth", [None, 25, 5])
@pytest.mark.parametrize("scenario", sorted(SCENARIOS))
def test_result_page_and_duel_close_give_the_same_total(monkeypatch, _models, scenario, sixth, chef):
    rows = SCENARIOS[scenario] + ([row(77, sixth, 20)] if sixth is not None else [])
    setup(monkeypatch, _models, status=[F, F, F], rows=rows)
    s = sel(substitute=SUB, sixth=SIXTH if sixth is not None else None, chef=chef)

    duel = asyncio.run(sel_svc.score_full_selection(s, NIGHT))
    result = asyncio.run(ss.resolve_substitution(STARTERS, SUB, NIGHT, closing=True))
    page = sel_svc.total_from_scores(s, by_id(rows), starters=result.starters)
    assert page == duel


# ── get_match_result end to end ──────────────────────────────────────────────

def result_page(monkeypatch, _models, *, status, rows, home, away, match_status="completed",
                viewer_is="H", hidden=False, lock_in=0):
    setup(monkeypatch, _models, status=status, rows=rows)
    users = {
        k: SimpleNamespace(id=k, auto_id=i, team_name=k, email=f"{k}@x", full_name=k,
                           team_logo="", jersey_index=0)
        for i, k in enumerate(("H", "A"), start=1)
    }
    match = SimpleNamespace(
        id="M", auto_id=1, home_user_id="H", away_user_id="A", status=match_status,
        nba_date=NIGHT, home_score=0, away_score=0, is_playoff=False,
        created_at=datetime(2026, 10, 6, tzinfo=timezone.utc),
    )

    def finder(items):
        def find(*_):
            async def to_list():
                return items

            return SimpleNamespace(to_list=to_list)

        return find

    class League:
        auto_id = _F()

        @staticmethod
        async def find_one(*_):
            return SimpleNamespace(id="L", auto_id=1, name="Lg")

    class Match:
        league_id = match_day = _F()
        find = staticmethod(finder([match]))

    class Users:
        find = staticmethod(finder(list(users.values())))

    class Sels:
        find = staticmethod(finder([home, away]))

    async def lock(*_):
        return lock_in

    import app.modules.leagues.playoff_labels as pl
    import app.modules.leagues.score_visibility as sv

    monkeypatch.setattr(sel_svc, "League", League)
    monkeypatch.setattr(sel_svc, "LeagueMatch", Match)
    monkeypatch.setattr(sel_svc, "User", Users)
    monkeypatch.setattr(sel_svc, "FlutterPlayerSelection", Sels)
    monkeypatch.setattr(sel_svc, "_lock_in_seconds", lock)
    async def rounds(*_):
        return {}

    monkeypatch.setattr(pl, "rounds_by_series", rounds)
    monkeypatch.setattr(pl, "label_of", lambda *_: (None, None))
    monkeypatch.setattr(sv, "scores_hidden", lambda *a, **k: hidden)
    monkeypatch.setattr(sv, "release_iso", lambda *_: "2026-10-07T09:00:00+02:00")
    sel_svc.clear_match_result_cache()
    out = asyncio.run(sel_svc.get_match_result(1, 1, users[viewer_is]))
    return {ps["team_name"]: ps for ps in out["player_scores"]}


AWAY_PLAIN = sel(user="A")      # same five players, no substitute


@pytest.mark.parametrize("chef", [False, True])
@pytest.mark.parametrize("with_sixth", [False, True])
def test_page_total_equals_the_duel_close_total(monkeypatch, _models, chef, with_sixth):
    rows = ABSENT_1 + SUB_ROW + [row(77, 25, 20)]
    home = sel(substitute=SUB, sixth=SIXTH if with_sixth else None, chef=chef)
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=rows, home=home, away=AWAY_PLAIN)
    duel = asyncio.run(sel_svc.score_full_selection(home, NIGHT))
    assert page["H"]["total_points"] == int(round(duel))


def test_page_shows_the_substitution_published(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + SUB_ROW,
                       home=sel(substitute=SUB), away=AWAY_PLAIN)["H"]
    assert page["total_points"] == 97
    assert page["substitution"] == {"status": "entered", "replaced_id": oid(1)}
    assert page["substitute"]["id"] == oid(99) and page["substitute"]["score"] == 22
    assert [i.get("absent") for i in page["selection"]].count(True) == 1
    assert len(page["selection"]) == 5                     # the substitute is not a 6th item


def test_page_before_the_close_waits_for_every_game(monkeypatch, _models):
    # day not published, a game still on: no replacement shown, #1 counts 0
    page = result_page(monkeypatch, _models, status=[F, L, F], rows=ABSENT_1 + SUB_ROW,
                       home=sel(substitute=SUB), away=AWAY_PLAIN, match_status="live")["H"]
    assert page["substitution"] == {"status": "pending", "replaced_id": None}
    assert page["total_points"] == 30 + 20 + 15 + 10
    # #1 played no minute and his game is final: OUT. Nobody is replaced yet.
    assert [i.get("absent") for i in page["selection"]] == [True, None, None, None, None]


def test_page_not_final_game_never_replaces_before_the_close(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[S, F, F], rows=ALL[1:] + SUB_ROW,
                       home=sel(substitute=SUB), away=AWAY_PLAIN, match_status="scheduled")["H"]
    assert page["substitution"]["status"] == "pending"
    assert not any(i.get("absent") for i in page["selection"])    # his game has not been played: not OUT


def test_opponent_lineup_and_substitute_stay_hidden_until_tip_off(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[S, S, S], rows=[], home=sel(substitute=SUB),
                       away=sel(substitute=SUB, user="A"), match_status="scheduled", viewer_is="H",
                       lock_in=3600)
    assert page["A"]["selection_hidden"] is True
    assert page["A"]["selection"] == [] and page["A"]["substitute"] is None


def test_paywall_blanks_the_substitute_score_too(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1 + SUB_ROW,
                       home=sel(substitute=SUB), away=AWAY_PLAIN, hidden=True)["H"]
    assert page["total_points"] == 0 and page["substitute"]["score"] == 0


def test_page_without_substitute_has_no_substitution(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=ALL, home=sel(), away=AWAY_PLAIN)["H"]
    assert page["total_points"] == 115
    assert page["substitute"] is None and page["substitution"] is None


# ── repair scripts: the duel totals they print include the substitute ────────

def _load_script(name):
    import importlib.util
    from pathlib import Path

    path = Path(__file__).resolve().parents[3] / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"script_{name}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _script_world(monkeypatch, _models, mod, rows, home, away):
    setup(monkeypatch, _models, status=[F, F, F], rows=rows)
    match = SimpleNamespace(home_user_id="H", away_user_id="A", league_id="L", match_day=1, is_playoff=False)
    sels = {"H": home, "A": away}

    def finder(items):
        def find(*_):
            async def to_list():
                return items

            return SimpleNamespace(to_list=to_list)

        return find

    class Stats:
        nba_date = _F()
        find = staticmethod(finder(rows))

    class Matches:
        nba_date = _F()
        find = staticmethod(finder([match]))

    class Leagues:
        @staticmethod
        async def get(_):
            return SimpleNamespace(auto_id=1)

    class Sels:
        user_id = league_auto_id = match_day = _F()

        @staticmethod
        async def find_one(uid, *_):
            return sels[uid]

    monkeypatch.setattr(mod, "PlayerGameStats", Stats)
    monkeypatch.setattr(mod, "LeagueMatch", Matches)
    monkeypatch.setattr(mod, "League", Leagues)
    monkeypatch.setattr(mod, "FlutterPlayerSelection", Sels)


def test_rescore_rounding_duel_totals_count_the_substitute(monkeypatch, _models):
    mod = _load_script("rescore_rounding")
    _script_world(monkeypatch, _models, mod, ABSENT_1 + SUB_ROW, sel(substitute=SUB), sel(user="A"))
    # the substitute's score is corrected 22 -> 30: home goes 97 -> 105, away stays 75
    rows = asyncio.run(mod._duels(NIGHT, {oid(99): 30.0}))
    assert [(old, new) for _lg, _m, old, new, _flip in rows] == [((97.0, 75.0), (105.0, 75.0))]


def test_resync_night_duel_totals_count_the_substitute(monkeypatch, _models):
    mod = _load_script("resync_night")
    _script_world(monkeypatch, _models, mod, ABSENT_1 + SUB_ROW, sel(substitute=SUB), sel(user="A"))
    lines = asyncio.run(mod._duel_totals(NIGHT, {oid(99): 30}))
    assert lines == ["  league 1 day 1: 97.0-75.0 -> 105.0-75.0"]


def test_scripts_without_substitute_print_what_they_always_printed(monkeypatch, _models):
    mod = _load_script("resync_night")
    _script_world(monkeypatch, _models, mod, ALL + SUB_ROW, sel(), sel(user="A"))
    lines = asyncio.run(mod._duel_totals(NIGHT, {oid(1): 50}))          # #1 corrected 40 -> 50
    assert lines == ["  league 1 day 1: 115.0-115.0 -> 125.0-125.0"]


# ── a starter with no minute is OUT in a duel too, with or without a substitute ──

def test_page_flags_the_out_starter_without_any_substitute(monkeypatch, _models):
    pages = result_page(monkeypatch, _models, status=[F, F, F], rows=ABSENT_1,
                        home=sel(), away=AWAY_PLAIN)
    assert [i.get("absent") for i in pages["H"]["selection"]] == [True, None, None, None, None]
    assert pages["H"]["substitute"] is None and pages["H"]["substitution"] is None


def test_page_a_postponed_game_without_row_is_out_at_the_close(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[S, F, F], rows=ALL[1:],
                       home=sel(), away=AWAY_PLAIN)["H"]
    assert [i.get("absent") for i in page["selection"]].count(True) == 1


def test_page_a_player_who_played_and_scored_zero_is_not_out(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=[row(1, 0, 30)] + ALL[1:],
                       home=sel(), away=AWAY_PLAIN)["H"]
    assert not any(i.get("absent") for i in page["selection"])


def test_page_the_sixth_man_is_never_flagged(monkeypatch, _models):
    page = result_page(monkeypatch, _models, status=[F, F, F], rows=ALL,       # no row for the 6th Man
                       home=sel(sixth=SIXTH), away=AWAY_PLAIN)["H"]
    sixth = [i for i in page["selection"] if i.get("is_sixth_man")]
    assert len(sixth) == 1 and not sixth[0].get("absent")

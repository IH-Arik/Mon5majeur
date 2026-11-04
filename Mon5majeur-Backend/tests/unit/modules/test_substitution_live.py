"""Substitute, live vs close: "no stat row = 0 minute" only holds at the close.

Live (closing=False) nothing is decided until the game of EVERY player of the
lineup (five starters + substitute) is final in the games table.
"""
from __future__ import annotations

import asyncio
from datetime import date
from types import SimpleNamespace

from beanie import PydanticObjectId

from app.modules.leagues import global_router as gr
from app.modules.leagues import substitution_service as ss
from app.modules.leagues.substitution import ENTERED, NOT_ENTERED, NONE, PENDING

NIGHT = date(2026, 10, 6)

# player number -> (team, price). 1 = 15M ... 5 = 5M, 99 = the substitute.
TEAMS = {
    1: "Los Angeles Lakers", 2: "Boston Celtics", 3: "Golden State Warriors",
    4: "Milwaukee Bucks", 5: "Denver Nuggets", 99: "Dallas Mavericks",
}
PRICES = {1: 15, 2: 12, 3: 10, 4: 8, 5: 5, 99: 7}
GAMES = [  # (home, away) -> every team above plays
    ("Los Angeles Lakers", "Boston Celtics"),
    ("Golden State Warriors", "Milwaukee Bucks"),
    ("Denver Nuggets", "Dallas Mavericks"),
]


class _F:
    def __eq__(self, other):
        return other

    def __hash__(self):
        return 0


def oid(n: int) -> str:
    return f"{n:024x}"


def person(n: int) -> dict:
    return {"id": oid(n), "name": f"P{n}", "position": "PG", "price": f"{PRICES[n]}M"}


STARTERS = [person(n) for n in (1, 2, 3, 4, 5)]
SUB = person(99)


def row(n: int, score: float, minutes: int):
    return SimpleNamespace(
        player_id=PydanticObjectId(oid(n)), fantasy_score=score, score_computed=True,
        minutes_played=minutes, did_not_play=minutes == 0, nba_date=NIGHT,
    )


def world(monkeypatch, *, status, rows):
    """status: game index (0..2) -> scheduled|live|final. rows: stat rows that exist."""
    by_pid = {str(r.player_id): r for r in rows}
    games = [
        SimpleNamespace(
            home_team_name=h, away_team_name=a, home_team_id=h[:3].upper(), away_team_id=a[:3].upper(),
            status=status[i], nba_date=NIGHT,
        )
        for i, (h, a) in enumerate(GAMES)
    ]
    players = [
        SimpleNamespace(id=PydanticObjectId(oid(n)), team_name=t, team_goalserve_id=t[:3].upper())
        for n, t in TEAMS.items()
    ]

    class Stats:
        player_id = nba_date = score_computed = _F()

        @staticmethod
        async def find_one(pid, *_):
            return by_pid.get(str(pid))

        @staticmethod
        def find(query):
            wanted = {str(x) for x in query["player_id"]["$in"]}

            async def to_list():
                return [r for k, r in by_pid.items() if k in wanted]

            return SimpleNamespace(to_list=to_list)

    class Games:
        nba_date = _F()

        @staticmethod
        def find(*_):
            async def to_list():
                return games

            return SimpleNamespace(to_list=to_list)

    class Players:
        @staticmethod
        def find(query):
            wanted = {str(x) for x in query["_id"]["$in"]}

            async def to_list():
                return [p for p in players if str(p.id) in wanted]

            return SimpleNamespace(to_list=to_list)

    monkeypatch.setattr(ss, "PlayerGameStats", Stats)
    monkeypatch.setattr(ss, "NBAGame", Games)
    monkeypatch.setattr(ss, "Player", Players)
    monkeypatch.setattr(gr, "PlayerGameStats", Stats)
    return by_pid


def resolve(closing):
    return asyncio.run(ss.resolve_substitution(STARTERS, SUB, NIGHT, closing=closing))


# starter #1 (15M) 0 minute, everyone else played, substitute played
PLAYED = [row(2, 30, 30), row(3, 20, 30), row(4, 15, 30), row(5, 10, 30), row(99, 22, 25)]
F, L, S = "final", "live", "scheduled"


# ── the three cases asked for ────────────────────────────────────────────────

def test_live_starter_game_not_started_never_triggers(monkeypatch):
    world(monkeypatch, status=[S, F, F], rows=PLAYED)           # #1's game has not started: no row
    r = resolve(closing=False)
    assert r.status == PENDING and r.starters == STARTERS and r.replaced is None


def test_live_starter_game_in_progress_at_zero_minute_never_triggers(monkeypatch):
    world(monkeypatch, status=[L, F, F], rows=[row(1, 0, 0)] + PLAYED)   # row exists, 0 min so far
    r = resolve(closing=False)
    assert r.status == PENDING and r.starters == STARTERS


def test_live_starter_game_final_at_zero_minute_is_replaced(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=[row(1, 0, 0)] + PLAYED)
    r = resolve(closing=False)
    assert r.status == ENTERED and r.replaced["id"] == oid(1)
    assert [p["id"] for p in r.starters][0] == oid(99)


# ── the rest of the live rule ────────────────────────────────────────────────

def test_live_waits_for_every_starter_not_only_the_absent_one(monkeypatch):
    # #1 is final at 0 minute but #3's game is still on: the most expensive
    # absent one could still change, so nothing is decided yet.
    world(monkeypatch, status=[F, L, F], rows=[row(1, 0, 0)] + PLAYED)
    assert resolve(closing=False).status == PENDING


def test_live_waits_for_the_substitute_game_too(monkeypatch):
    world(monkeypatch, status=[F, F, L], rows=[row(1, 0, 0)] + PLAYED[:-1] + [row(99, 4, 8)])
    assert resolve(closing=False).status == PENDING


def test_live_everyone_played_and_final_substitute_does_not_enter(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=[row(1, 40, 30)] + PLAYED)
    assert resolve(closing=False).status == NOT_ENTERED


def test_live_lineup_without_substitute_is_untouched(monkeypatch):
    world(monkeypatch, status=[L, L, L], rows=[])
    r = asyncio.run(ss.resolve_substitution(STARTERS, None, NIGHT, closing=False))
    assert r.status == NONE and r.starters == STARTERS


# ── close: the same data DOES replace (postponed game = 0 minute) ────────────

def test_close_postponed_game_without_row_counts_as_zero_minute(monkeypatch):
    world(monkeypatch, status=[S, F, F], rows=PLAYED)
    r = resolve(closing=True)
    assert r.status == ENTERED and r.replaced["id"] == oid(1)


def test_close_game_still_live_with_zero_minute_counts_as_zero_minute(monkeypatch):
    world(monkeypatch, status=[L, F, F], rows=[row(1, 0, 0)] + PLAYED)
    assert resolve(closing=True).status == ENTERED


def test_close_starter_with_minutes_in_unfinished_game_is_kept(monkeypatch):
    world(monkeypatch, status=[L, F, F], rows=[row(1, 12, 9)] + PLAYED)
    assert resolve(closing=True).status == NOT_ENTERED


# ── Global League screens ────────────────────────────────────────────────────

def _sel(substitute):
    return SimpleNamespace(selected_players=STARTERS, substitute_player=substitute)


def _global(monkeypatch, sel):
    class Sel:
        user_id = league_auto_id = match_day = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return sel

    monkeypatch.setattr(gr, "FlutterPlayerSelection", Sel)

    async def today():
        return NIGHT

    monkeypatch.setattr(gr, "_nba_today", today)


def total(monkeypatch, sel):
    _global(monkeypatch, sel)
    league = SimpleNamespace(id="L", auto_id=1)
    return asyncio.run(gr._global_total_for_user(league, "U", 1, NIGHT, use_archive=False))


STARTER_ROWS = [row(1, 40, 30), row(2, 30, 30), row(3, 20, 30), row(4, 15, 30), row(5, 10, 30)]  # 115


def test_live_total_without_substitute_is_the_plain_sum_as_before(monkeypatch):
    world(monkeypatch, status=[L, L, L], rows=STARTER_ROWS)
    assert total(monkeypatch, _sel(None)) == 115


def test_live_total_substitute_waits_while_a_game_is_on(monkeypatch):
    world(monkeypatch, status=[F, L, F], rows=[row(1, 0, 0)] + PLAYED)
    assert total(monkeypatch, _sel(SUB)) == 30 + 20 + 15 + 10      # #1 counts 0, no 22 yet


def test_live_total_substitute_counts_once_every_game_is_final(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=[row(1, 0, 0)] + PLAYED)
    assert total(monkeypatch, _sel(SUB)) == 22 + 30 + 20 + 15 + 10


def test_live_items_flag_the_absent_starter_and_give_the_substitute(monkeypatch):
    world(monkeypatch, status=[F, F, F], rows=[row(1, 0, 0)] + PLAYED)
    _global(monkeypatch, _sel(SUB))
    items, sub, state = asyncio.run(gr._global_selection_items("U", 1, 1, NIGHT, True))
    assert len(items) == 5 and [i.get("absent") for i in items] == [True, None, None, None, None]
    assert sub["id"] == oid(99) and sub["score"] == 22
    assert state == {"status": ENTERED, "replaced_id": oid(1)}


def test_live_items_pending_show_the_substitute_but_no_replacement(monkeypatch):
    world(monkeypatch, status=[F, L, F], rows=[row(1, 0, 0)] + PLAYED)
    _global(monkeypatch, _sel(SUB))
    items, sub, state = asyncio.run(gr._global_selection_items("U", 1, 1, NIGHT, True))
    assert not any(i.get("absent") for i in items)
    assert state == {"status": PENDING, "replaced_id": None}


def test_live_items_without_substitute_keep_their_old_shape(monkeypatch):
    world(monkeypatch, status=[L, L, L], rows=STARTER_ROWS)
    _global(monkeypatch, _sel(None))
    items, sub, state = asyncio.run(gr._global_selection_items("U", 1, 1, NIGHT, True))
    assert sub is None and state is None
    assert all(set(i) == {"id", "name", "position", "score"} for i in items)


def test_published_night_payload_uses_the_close_rule(monkeypatch):
    # postponed game for #1 (no row): at the close it counts 0 minute -> replaced
    world(monkeypatch, status=[S, F, F], rows=PLAYED)

    class Daily:
        user_id = league_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return SimpleNamespace(total_points=97)

    class Sel:
        user_id = league_auto_id = nba_date = _F()

        @staticmethod
        async def find_one(*_):
            return _sel(SUB)

    monkeypatch.setattr(gr, "GlobalLeagueDailyScore", Daily)
    monkeypatch.setattr(gr, "FlutterPlayerSelection", Sel)
    gr.clear_result_cache()
    out = asyncio.run(gr._night_payload(SimpleNamespace(id="L", auto_id=1), SimpleNamespace(id="U"), NIGHT))
    assert out["substitution"] == {"status": ENTERED, "replaced_id": oid(1)}
    assert out["substitute"]["id"] == oid(99)
    assert out["selection"][0]["absent"] is True
    assert out["total_points"] == 97                # the archived, published score

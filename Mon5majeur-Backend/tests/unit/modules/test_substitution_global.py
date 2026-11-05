"""Global League archive with the substitute: the score a night is published with."""
from __future__ import annotations

import asyncio
from datetime import date
from types import SimpleNamespace

from beanie import PydanticObjectId

from app.modules.leagues import global_score_service as gss
from app.modules.leagues import substitution_service as ss

NIGHT = date(2026, 10, 6)


class _F:
    def __eq__(self, other):          # `Model.field == x` -> x, like the other stubs
        return other

    def __hash__(self):
        return 0


def oid(n: int) -> str:
    return f"{n:024x}"


def player(n: int, price: int) -> dict:
    return {"id": oid(n), "name": f"P{n}", "position": "PG", "price": f"{price}M"}


def stat(n: int, score: float, minutes: int = 30):
    return SimpleNamespace(
        player_id=PydanticObjectId(oid(n)), fantasy_score=score, score_computed=True,
        minutes_played=minutes, did_not_play=minutes == 0, nba_date=NIGHT,
    )


def run(monkeypatch, *, selected, substitute, stats):
    """Archive one night for one Global League member; returns (score, db_queries)."""
    by_pid = {str(s.player_id): s for s in stats}
    inserted: list = []
    queries = {"stats_find": 0}

    class Stats:
        player_id = nba_date = _F()

        @staticmethod
        async def find_one(pid, _date):
            return by_pid.get(str(pid))

        @staticmethod
        def find(query):
            queries["stats_find"] += 1
            wanted = {str(x) for x in query["player_id"]["$in"]}

            async def to_list():
                return [s for k, s in by_pid.items() if k in wanted]

            return SimpleNamespace(to_list=to_list)

    sel = SimpleNamespace(user_id="U", selected_players=selected, substitute_player=substitute)
    league = SimpleNamespace(id="L", auto_id=1, current_match_day=1)

    async def league_save():
        return None

    league.save = league_save

    class League:
        type = _F()

        @staticmethod
        async def find_one(*_):
            return league

    class Sel:
        league_auto_id = nba_date = _F()

        @staticmethod
        def find(*_):
            async def to_list():
                return [sel]

            return SimpleNamespace(to_list=to_list)

    class Daily:
        user_id = league_id = nba_date = _F()

        def __init__(self, **kw):
            self.__dict__.update(kw)

        @staticmethod
        async def find_one(*_):
            return None

        async def insert(self):
            inserted.append(self)

    for mod in (gss,):
        monkeypatch.setattr(mod, "League", League)
        monkeypatch.setattr(mod, "FlutterPlayerSelection", Sel)
        monkeypatch.setattr(mod, "GlobalLeagueDailyScore", Daily)
        monkeypatch.setattr(mod, "PlayerGameStats", Stats)
    monkeypatch.setattr(ss, "PlayerGameStats", Stats)

    class NoGames:                      # only read by the close-time warning trace
        nba_date = _F()

        @staticmethod
        def find(*_):
            async def to_list():
                return []

            return SimpleNamespace(to_list=to_list)

    monkeypatch.setattr(ss, "NBAGame", NoGames)
    monkeypatch.setattr(ss, "Player", NoGames)

    asyncio.run(gss.archive_daily_scores(NIGHT))
    assert len(inserted) == 1
    return inserted[0].total_points, queries["stats_find"]


STARTERS = [player(1, 15), player(2, 12), player(3, 10), player(4, 8), player(5, 5)]
SUB = player(99, 7)
BASE = [stat(1, 40), stat(2, 30), stat(3, 20), stat(4, 15), stat(5, 10)]   # = 115


def test_lineup_without_substitute_scores_exactly_as_before(monkeypatch):
    score, extra_queries = run(monkeypatch, selected=STARTERS, substitute=None, stats=BASE)
    assert score == 115.0
    assert extra_queries == 0          # old lineups cost no extra query


def test_substitute_stays_out_when_everyone_played(monkeypatch):
    score, _ = run(monkeypatch, selected=STARTERS, substitute=SUB, stats=BASE + [stat(99, 50)])
    assert score == 115.0              # his 50 points do not count


def test_absent_starter_is_replaced_by_the_substitute(monkeypatch):
    stats = [stat(1, 0, minutes=0)] + BASE[1:] + [stat(99, 22)]
    score, _ = run(monkeypatch, selected=STARTERS, substitute=SUB, stats=stats)
    assert score == 30 + 20 + 15 + 10 + 22


def test_substitute_who_did_not_play_enters_for_zero_point(monkeypatch):
    stats = [stat(1, 0, minutes=0)] + BASE[1:] + [stat(99, 0, minutes=0)]
    score, _ = run(monkeypatch, selected=STARTERS, substitute=SUB, stats=stats)
    assert score == 30 + 20 + 15 + 10


def test_postponed_game_without_stat_row_counts_as_zero_minute(monkeypatch):
    stats = BASE[1:] + [stat(99, 18)]                  # starter 1 has no row at all
    score, _ = run(monkeypatch, selected=STARTERS, substitute=SUB, stats=stats)
    assert score == 30 + 20 + 15 + 10 + 18


def test_two_absent_starters_only_the_most_expensive_is_replaced(monkeypatch):
    stats = [stat(1, 0, 0), stat(2, 0, 0)] + BASE[2:] + [stat(99, 25)]
    score, _ = run(monkeypatch, selected=STARTERS, substitute=SUB, stats=stats)
    assert score == 25 + 0 + 20 + 15 + 10              # #1 (15M) replaced, #2 stays at 0


def test_starter_under_10m_absent_is_not_replaced(monkeypatch):
    stats = BASE[:4] + [stat(5, 0, 0)] + [stat(99, 25)]
    score, _ = run(monkeypatch, selected=STARTERS, substitute=SUB, stats=stats)
    assert score == 40 + 30 + 20 + 15

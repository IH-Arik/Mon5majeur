"""Arik QA item 3: a matchup recorded twice, one copy stuck live."""
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

from app.modules.players.nba_night import drop_duplicate_games, stuck_live_games

NIGHT = date(2026, 10, 21)
NOW = datetime(2026, 10, 22, 8, 0, tzinfo=timezone.utc)


def _g(gid, status, home="NOP", away="WAS", tip_hours_ago=8):
    return SimpleNamespace(goalserve_id=gid, status=status, nba_date=NIGHT,
                           home_team_id=home, away_team_id=away,
                           tip_off_time=NOW - timedelta(hours=tip_hours_ago))


def test_the_finished_copy_is_kept_and_the_stuck_one_dropped():
    games = [_g("a", "live"), _g("b", "final"), _g("c", "final", home="LAC", away="SAC")]
    assert [g.goalserve_id for g in drop_duplicate_games(games)] == ["b", "c"]


def test_a_single_game_is_never_dropped():
    games = [_g("a", "live")]
    assert drop_duplicate_games(games) == games


def test_a_game_live_for_hours_is_reported_as_stuck():
    assert [g.goalserve_id for g in stuck_live_games([_g("a", "live", tip_hours_ago=6)], NOW)] == ["a"]


def test_a_game_in_progress_is_not_stuck():
    assert stuck_live_games([_g("a", "live", tip_hours_ago=2)], NOW) == []
    assert stuck_live_games([_g("b", "final", tip_hours_ago=9)], NOW) == []

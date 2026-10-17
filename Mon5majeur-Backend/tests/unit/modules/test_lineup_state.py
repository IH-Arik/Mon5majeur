import asyncio
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from app.modules.leagues import lineup_state as ls

TIP = datetime(2026, 10, 14, 0, 0, tzinfo=timezone.utc)
CUTOFF = datetime(2026, 10, 14, 7, 0, tzinfo=timezone.utc)


def test_before_the_first_tip_off_it_is_open_with_a_countdown():
    state, lock = ls.decide_state(TIP - timedelta(minutes=30), TIP, False, CUTOFF)
    assert (state, lock) == (ls.OPEN, 1800)


def test_during_the_games_it_is_locked():
    state, lock = ls.decide_state(TIP + timedelta(hours=2), TIP, False, CUTOFF)
    assert (state, lock) == (ls.LOCKED, 0)


def test_after_the_last_final_game_and_before_the_publication():
    state, lock = ls.decide_state(TIP + timedelta(hours=6), TIP, True, CUTOFF)
    assert (state, lock) == (ls.WAITING_RESULTS, 0)


def test_past_the_cutoff_it_is_never_editable_again_for_that_night():
    state, lock = ls.decide_state(CUTOFF + timedelta(minutes=1), TIP, False, CUTOFF)
    assert (state, lock) == (ls.WAITING_RESULTS, 0)


def test_no_game_means_not_playing_and_no_lock():
    assert ls.decide_state(TIP, None, False, CUTOFF) == (ls.NOT_PLAYING, None)


def test_only_an_open_lineup_that_is_not_saved_is_concerned():
    assert ls.LineupState(ls.OPEN, 600, False).concerned
    assert not ls.LineupState(ls.OPEN, 600, True).concerned
    assert not ls.LineupState(ls.LOCKED, 0, False).concerned
    assert not ls.LineupState(ls.NOT_PLAYING, None, False).concerned


def _league(**kw):
    base = dict(type="private", status="playoffs", id="L", auto_id=3, current_match_day=9)
    base.update(kw)
    return SimpleNamespace(**base)


def test_qualified_player_with_no_game_is_not_playing():
    fake_match = MagicMock()
    fake_match.find_one = AsyncMock(return_value=None)
    with patch("app.modules.leagues.model.LeagueMatch", fake_match):
        info = asyncio.run(ls.league_state(_league(), "U"))
    assert info.state == ls.NOT_PLAYING
    assert not info.concerned


def test_player_with_a_game_and_no_lineup_is_concerned():
    match = SimpleNamespace(nba_date=date(2026, 10, 13))
    fake_match = MagicMock()
    fake_match.find_one = AsyncMock(return_value=match)
    fake_sel = MagicMock()
    fake_sel.find_one = AsyncMock(return_value=None)
    now = TIP - timedelta(hours=5)
    with patch("app.modules.leagues.model.LeagueMatch", fake_match), \
            patch("app.modules.lineups.compat_model.FlutterPlayerSelection", fake_sel), \
            patch("app.modules.players.nba_night.composing_night",
                  AsyncMock(return_value=date(2026, 10, 13))), \
            patch.object(ls, "night_facts", AsyncMock(return_value=(TIP, False))):
        info = asyncio.run(ls.league_state(_league(), "U", now))
    assert info.state == ls.OPEN and info.concerned


def test_player_with_a_saved_lineup_is_not_concerned():
    match = SimpleNamespace(nba_date=date(2026, 10, 13))
    fake_match = MagicMock()
    fake_match.find_one = AsyncMock(return_value=match)
    fake_sel = MagicMock()
    fake_sel.find_one = AsyncMock(return_value=object())
    now = TIP - timedelta(hours=5)
    with patch("app.modules.leagues.model.LeagueMatch", fake_match), \
            patch("app.modules.lineups.compat_model.FlutterPlayerSelection", fake_sel), \
            patch("app.modules.players.nba_night.composing_night",
                  AsyncMock(return_value=date(2026, 10, 13))), \
            patch.object(ls, "night_facts", AsyncMock(return_value=(TIP, False))):
        info = asyncio.run(ls.league_state(_league(), "U", now))
    assert info.state == ls.OPEN and info.submitted and not info.concerned


def test_a_league_not_started_has_no_state():
    info = asyncio.run(ls.league_state(_league(status="waiting"), "U"))
    assert info.state is None and info.lock_in_seconds is None

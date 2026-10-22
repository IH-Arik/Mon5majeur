"""Arik QA item 4: duel team save rules."""
import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.exceptions.errors import ForbiddenException
from app.modules.leagues import selection_service as ss


def test_the_sixth_man_cannot_also_be_a_starter():
    starters = [{"id": str(i)} for i in range(5)]
    with pytest.raises(ForbiddenException, match="6th Man cannot also be a starter"):
        ss._check_sixth_man_not_starter(starters, {"id": 3})


def test_a_different_sixth_man_is_accepted():
    starters = [{"id": str(i)} for i in range(5)]
    ss._check_sixth_man_not_starter(starters, {"id": "9"})
    ss._check_sixth_man_not_starter(starters, None)


LEAGUE = SimpleNamespace(id="L", auto_id=7, budget=100, type="public", current_match_day=3)
USER = SimpleNamespace(id="U")
TEAM = [{"id": str(i), "price": "10M"} for i in range(5)]


def _save(member=True, match=True, can_use=True, existing=None, consume_fails=False, seen=None):
    leagues = MagicMock()
    leagues.find_one = AsyncMock(return_value=LEAGUE)
    leagues.auto_id = MagicMock()
    memberships = MagicMock()
    memberships.find_one = AsyncMock(return_value=object() if member else None)
    matches = MagicMock()
    matches.find_one = AsyncMock(return_value=SimpleNamespace(
        nba_date="2026-10-20", is_playoff=False, auto_id=11) if match else None)
    sels = MagicMock()
    sels.find_one = AsyncMock(return_value=existing)
    inserted = SimpleNamespace(delete=AsyncMock())
    if seen is not None:
        seen['inserted'] = inserted
    sels.return_value.insert = AsyncMock(return_value=inserted)
    bonus = MagicMock()
    bonus.return_value.can_use = AsyncMock(return_value=can_use)
    sync = AsyncMock(side_effect=ForbiddenException("x") if consume_fails else None)
    info = SimpleNamespace(lock_in_seconds=600)
    with patch.object(ss, "League", leagues), \
            patch("app.modules.leagues.model.LeagueMembership", memberships), \
            patch.object(ss, "LeagueMatch", matches), \
            patch.object(ss, "FlutterPlayerSelection", sels), \
            patch("app.modules.bonuses.service.BonusService", bonus), \
            patch.object(ss, "_sync_bonus", sync), \
            patch.object(ss, "_validate_selection", AsyncMock()), \
            patch("app.modules.leagues.lineup_state.ensure_open", AsyncMock(return_value=info)):
        out = asyncio.run(ss.save_player_selection(7, 3, TEAM, USER, chef_curry=True))
    return out, sels, sync, inserted


def test_a_non_member_cannot_save_in_a_public_league():
    with pytest.raises(ForbiddenException, match="not a member"):
        _save(member=False)


def test_a_player_without_a_match_that_day_is_refused():
    with pytest.raises(ForbiddenException, match="no match"):
        _save(match=False)


def test_a_bonus_without_uses_left_is_refused_before_anything_is_written():
    with pytest.raises(ForbiddenException, match="chef curry"):
        _save(can_use=False)


def test_the_save_answers_with_the_lock():
    out, _, sync, _ = _save()
    assert out["lock_in_seconds"] == 600 and out["match_id"] == 11
    assert sync.await_count == 3


def test_a_failed_bonus_debit_removes_the_team_it_just_wrote():
    seen = {}
    with pytest.raises(ForbiddenException):
        _save(consume_fails=True, seen=seen)
    seen["inserted"].delete.assert_awaited_once()


def test_a_failed_bonus_debit_puts_the_previous_team_back():
    old_team = [{"id": "a"}]
    existing = SimpleNamespace(
        selected_players=old_team, submitted_at=None, nba_date=None,
        luxury_tax=False, chef_curry=False, sixth_man_player=None, save=AsyncMock(),
    )
    with pytest.raises(ForbiddenException):
        _save(consume_fails=True, existing=existing)
    assert existing.selected_players == old_team and existing.chef_curry is False

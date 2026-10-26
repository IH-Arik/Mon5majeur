"""Arik QA item 10: a finished league survives its own Delete; Replay recreates
one with the same roster."""
import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.exceptions.errors import BadRequestException, ForbiddenException, NotFoundException
from app.modules.leagues import service as svc_mod
from app.modules.leagues.service import LeagueService, _visible_to


def _league(status="completed", hidden_by=None, admin="A", replayed=None):
    return SimpleNamespace(
        id="L", auto_id=9, status=status, admin_id=admin,
        hidden_by=list(hidden_by or []), save=AsyncMock(), delete=AsyncMock(),
        replayed_as_auto_id=replayed, type="private", name="Rob1 league",
        budget=100, max_size=6, description="", logo="", current_size=4,
    )


def test_visible_to_drops_a_league_the_user_hid():
    a, b = _league(hidden_by=["U"]), _league(hidden_by=[])
    assert _visible_to([a, b], "U") == [b]


def _svc(league):
    league_repo = SimpleNamespace(get=AsyncMock(return_value=league))
    membership_repo = SimpleNamespace(get_membership=AsyncMock(return_value=object()))
    return LeagueService(league_repo, membership_repo, None)


def test_a_waiting_league_is_still_really_deleted():
    league = _league(status="waiting")
    memberships = MagicMock()
    memberships.find = MagicMock(return_value=SimpleNamespace(delete=AsyncMock()))
    memberships.league_id = None
    s = _svc(league)
    with patch.object(svc_mod, "LeagueMembership", memberships):
        asyncio.run(s.delete_league("L", SimpleNamespace(id="A", is_superuser=False)))
    league.delete.assert_awaited_once()
    league.save.assert_not_awaited()


def test_a_finished_league_is_hidden_for_its_creator_not_deleted():
    league = _league(status="completed")
    s = _svc(league)
    asyncio.run(s.delete_league("L", SimpleNamespace(id="A", is_superuser=False)))
    league.delete.assert_not_awaited()
    league.save.assert_awaited_once()
    assert league.hidden_by == ["A"]


def test_hiding_twice_does_not_duplicate():
    league = _league(status="completed", hidden_by=["A"])
    s = _svc(league)
    asyncio.run(s.delete_league("L", SimpleNamespace(id="A", is_superuser=False)))
    assert league.hidden_by == ["A"]


def test_a_live_league_still_cannot_be_deleted():
    league = _league(status="regular_season")
    s = _svc(league)
    with pytest.raises(BadRequestException):
        asyncio.run(s.delete_league("L", SimpleNamespace(id="A", is_superuser=False)))


# --- replay -------------------------------------------------------------------------------

def _replay_env(league, old_members):
    leagues = MagicMock()
    leagues.find_one = AsyncMock(return_value=league)
    created = {}

    def _new_league(**kw):
        obj = SimpleNamespace(id="NEW", auto_id=None, save=AsyncMock(), **kw)
        created["league"] = obj
        return obj

    insert = AsyncMock(side_effect=lambda: created["league"])
    membership_repo = SimpleNamespace(get_league_members=AsyncMock(return_value=old_members))
    s = LeagueService(None, membership_repo, None)
    return s, leagues, created, insert


def test_replay_creates_a_new_league_with_the_old_roster():
    league = _league(status="completed", admin="A")
    old_members = [SimpleNamespace(user_id="A"), SimpleNamespace(user_id="B"),
                   SimpleNamespace(user_id="C")]
    s, leagues, created, insert = _replay_env(league, old_members)
    memberships_inserted = []

    def _membership(**kw):
        obj = SimpleNamespace(**kw)
        obj.insert = AsyncMock(side_effect=lambda: memberships_inserted.append(kw))
        return obj

    from datetime import datetime, timezone

    def _fake_insert(**kw):
        return SimpleNamespace(
            id="NEW", auto_id=None, save=AsyncMock(), status="waiting",
            invite_code="ABCDEFGH", created_at=datetime.now(timezone.utc),
            started_at=None, current_match_day=0, current_week=0, **kw,
        )

    with patch.object(svc_mod, "League", leagues), \
            patch.object(svc_mod, "_insert_with_invite_code", AsyncMock(side_effect=_fake_insert)), \
            patch("app.database.counters.next_seq", AsyncMock(return_value=99)), \
            patch.object(svc_mod, "LeagueMembership", _membership), \
            patch("app.modules.users.model.User") as users:
        users.find = MagicMock(return_value=SimpleNamespace(to_list=AsyncMock(return_value=[])))
        users.get = AsyncMock(return_value=None)
        out = asyncio.run(s.replay_league(9, "private", SimpleNamespace(id="A", is_superuser=False)))
    assert len(memberships_inserted) == 3  # A, B, C
    assert league.replayed_as_auto_id == 99
    league.save.assert_awaited()


def test_a_second_replay_is_refused():
    league = _league(status="completed", replayed=42)
    s, leagues, _c, _i = _replay_env(league, [])
    with patch.object(svc_mod, "League", leagues):
        with pytest.raises(BadRequestException, match="already replayed"):
            asyncio.run(s.replay_league(9, "private", SimpleNamespace(id="A", is_superuser=False)))


def test_only_the_creator_can_replay():
    league = _league(status="completed", admin="A")
    s, leagues, _c, _i = _replay_env(league, [])
    with patch.object(svc_mod, "League", leagues):
        with pytest.raises(ForbiddenException):
            asyncio.run(s.replay_league(9, "private", SimpleNamespace(id="OTHER", is_superuser=False)))


def test_a_league_still_in_progress_cannot_be_replayed():
    league = _league(status="regular_season")
    s, leagues, _c, _i = _replay_env(league, [])
    with patch.object(svc_mod, "League", leagues):
        with pytest.raises(BadRequestException, match="not finished"):
            asyncio.run(s.replay_league(9, "private", SimpleNamespace(id="A", is_superuser=False)))


def test_unknown_league():
    s, leagues, _c, _i = _replay_env(None, [])
    with patch.object(svc_mod, "League", leagues):
        with pytest.raises(NotFoundException):
            asyncio.run(s.replay_league(9, "private", SimpleNamespace(id="A", is_superuser=False)))

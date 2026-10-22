"""Arik QA item 2: OUT players come from the injury report."""
import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from app.modules.players import service as svc_mod
from app.modules.players.service import PlayerService


class _P(SimpleNamespace):
    async def save_updated(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)

    async def save(self):
        pass


def _player(name, is_out=False, uncertain=False):
    return _P(id=name, full_name=name, is_out=is_out, out_reason=None,
              is_uncertain=uncertain, injury_checked_at=None)


def _sync(players, report, fail=False):
    fake = MagicMock()

    class _Q:
        async def to_list(self):
            return players
    fake.find = MagicMock(return_value=_Q())
    fake.is_active = MagicMock()
    fetch = AsyncMock(side_effect=RuntimeError("down")) if fail else AsyncMock(return_value=report)
    service = PlayerService.__new__(PlayerService)
    with patch.object(svc_mod, "Player", fake), \
            patch("app.modules.players.espn_roster.fetch_injuries", fetch), \
            patch("app.modules.notifications.service.NotificationService") as notif:
        notif.return_value.notify_player_out = AsyncMock()
        changed = asyncio.run(service.sync_injury_report())
    return changed, notif


REPORT = [
    {"full_name": "Maxime Raynaud", "team_name": "Sacramento Kings", "status": "Out",
     "comment": "Raynaud (knee) is expected to miss at least the first five games."},
    {"full_name": "Luka Dončić", "team_name": "Los Angeles Lakers", "status": "Day-To-Day",
     "comment": "ankle"},
]


def test_a_player_listed_out_is_out_and_his_holders_are_notified():
    raynaud = _player("Maxime Raynaud")
    _, notif = _sync([raynaud], REPORT)
    assert raynaud.is_out and "knee" in raynaud.out_reason
    notif.return_value.notify_player_out.assert_awaited_once()


def test_day_to_day_is_uncertain_but_not_out():
    luka = _player("Luka Doncic")       # accents ignored when matching
    _sync([luka], REPORT)
    assert luka.is_uncertain and not luka.is_out


def test_a_player_no_longer_listed_is_available_again():
    back = _player("Back Healthy", is_out=True, uncertain=False)
    _sync([back], REPORT)
    assert not back.is_out


def test_a_failed_report_changes_nothing():
    out = _player("Someone Out", is_out=True)
    changed, _ = _sync([out], [], fail=True)
    assert changed == 0 and out.is_out


def test_an_empty_report_changes_nothing():
    out = _player("Someone Out", is_out=True)
    changed, _ = _sync([out], [])
    assert changed == 0 and out.is_out

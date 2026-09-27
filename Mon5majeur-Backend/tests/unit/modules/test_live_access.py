"""QA 24/09 #6: the Shop showed Live Scoring "Active" while the live screen
stayed locked, because the two expiry fields had drifted apart."""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from app.modules.bonuses import live_access

NOW = datetime.now(timezone.utc)


class _Doc:
    def __init__(self, **fields):
        self.__dict__.update(fields)
        self.writes: list[dict] = []

    async def set(self, values):
        self.writes.append(values)
        for key, value in values.items():
            setattr(self, key, value)


def _stub(monkeypatch, inv):
    # Field expressions resolve to plain names so no Beanie init is needed.
    class _User:
        premium_until = "premium_until"

    class _Inventory:
        live_scoring_until = "live_scoring_until"
        user_id = "user_id"

        @staticmethod
        async def find_one(*_):
            return inv

    monkeypatch.setattr(live_access, "User", _User)
    monkeypatch.setattr(live_access, "UserBonusInventory", _Inventory)


def test_shop_expiry_ahead_unlocks_premium(monkeypatch):
    shop_until = (NOW + timedelta(days=20)).replace(tzinfo=None)  # naive, as Mongo returns it
    inv = _Doc(live_scoring_until=shop_until)
    user = _Doc(id=1, premium_until=None)
    _stub(monkeypatch, inv)

    asyncio.run(live_access.sync_live_scoring(user))

    assert user.premium_until == shop_until.replace(tzinfo=timezone.utc)
    assert inv.writes == []  # already the latest, left untouched


def test_admin_grant_ahead_shows_in_shop(monkeypatch):
    premium_until = NOW + timedelta(days=30)
    inv = _Doc(live_scoring_until=NOW - timedelta(days=1))
    user = _Doc(id=1, premium_until=premium_until)
    _stub(monkeypatch, inv)

    asyncio.run(live_access.sync_live_scoring(user, inv))

    assert inv.live_scoring_until == premium_until
    assert user.writes == []


def test_nothing_to_sync(monkeypatch):
    user = _Doc(id=1, premium_until=None)
    _stub(monkeypatch, None)

    assert asyncio.run(live_access.sync_live_scoring(user)) is None
    assert user.writes == []

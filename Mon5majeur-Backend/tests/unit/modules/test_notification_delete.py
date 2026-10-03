"""QA 30/09 #8 #2: notifications can be deleted, only by their owner."""
from __future__ import annotations

import asyncio

import pytest

from app.exceptions.errors import NotFoundException
from app.modules.notifications.service import NotificationService


class _Notif:
    def __init__(self, recipient):
        self.recipient_id = recipient
        self.deleted = False

    async def delete(self):
        self.deleted = True


class _Repo:
    def __init__(self, notif):
        self.notif = notif
        self.cleared_for = None

    async def get(self, _id):
        return self.notif

    async def delete_all(self, user_id):
        self.cleared_for = user_id


def test_owner_deletes_their_notification():
    n = _Notif("u1")
    asyncio.run(NotificationService(_Repo(n)).delete("n1", "u1"))
    assert n.deleted


def test_someone_elses_notification_is_not_found_and_kept():
    n = _Notif("u1")
    with pytest.raises(NotFoundException):
        asyncio.run(NotificationService(_Repo(n)).delete("n1", "u2"))
    assert not n.deleted


def test_missing_notification_is_not_found():
    with pytest.raises(NotFoundException):
        asyncio.run(NotificationService(_Repo(None)).delete("n1", "u1"))


def test_clear_all_is_scoped_to_the_user():
    repo = _Repo(None)
    asyncio.run(NotificationService(repo).delete_all("u1"))
    assert repo.cleared_for == "u1"

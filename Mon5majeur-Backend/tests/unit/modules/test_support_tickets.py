"""
Unit tests for support-ticket status transitions and the "awaiting admin"
flag — the two pieces of logic the inbox depends on and the easiest to get
subtly wrong.

Run standalone (the repo's tests/conftest.py is legacy SQLAlchemy and would
otherwise fail collection):
    ./.venv/Scripts/python.exe -m pytest tests/unit/modules/test_support_tickets.py --noconftest
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

import pytest

from app.exceptions.errors import BadRequestException
from app.modules.support.model import SupportTicket, TicketMessage
from app.modules.support.service import SupportService, _awaiting_admin


def _run(coro):
    return asyncio.run(coro)


def _msg(admin: bool, body: str = "hi") -> TicketMessage:
    return TicketMessage(body=body, author_is_admin=admin, author_name="x")


def _ticket(status: str = "open", messages=None) -> SupportTicket:
    """Build a ticket without touching the DB.

    model_construct skips validation and, crucially, the Document machinery
    that would demand an initialised Beanie connection.
    """
    now = datetime.now(timezone.utc)
    return SupportTicket.model_construct(
        user_id=None,
        user_email="player@example.com",
        user_name="Player",
        subject="Help",
        status=status,
        messages=messages if messages is not None else [_msg(False)],
        last_activity_at=now,
        created_at=now,
        updated_at=now,
    )


class _Admin:
    id = "admin-1"
    full_name = "Support Agent"
    team_name = None
    email = "admin@example.com"


def _patch_save(monkeypatch, ticket: SupportTicket | None = None):
    """save_updated normally hits Mongo; apply the fields in memory instead.

    Patched on the class: Pydantic models reject attribute assignment for
    names that are not declared fields, so the instance cannot carry it.
    """

    async def fake_save_updated(self, **kwargs):
        for k, v in kwargs.items():
            object.__setattr__(self, k, v)
        return self

    monkeypatch.setattr(SupportTicket, "save_updated", fake_save_updated)


def _patch_get(monkeypatch, ticket: SupportTicket):
    """Stub the by-id fetch the admin/player routes go through."""

    async def fake_get(_ticket_id):
        return ticket

    monkeypatch.setattr(SupportTicket, "get", fake_get)


# ── awaiting_admin ────────────────────────────────────────────────────────────

def test_awaiting_admin_when_player_spoke_last():
    assert _awaiting_admin(_ticket(messages=[_msg(False)])) is True


def test_not_awaiting_admin_when_admin_spoke_last():
    assert _awaiting_admin(_ticket(messages=[_msg(False), _msg(True)])) is False


def test_closed_ticket_never_awaits_a_reply():
    """A closed thread ending on the player's message must stay out of the
    queue — otherwise every closed ticket reads as outstanding work."""
    ticket = _ticket(status="closed", messages=[_msg(False)])
    assert _awaiting_admin(ticket) is False


def test_ticket_with_no_messages_awaits_nobody():
    assert _awaiting_admin(_ticket(messages=[])) is False


# ── admin reply ───────────────────────────────────────────────────────────────

def test_admin_reply_moves_open_to_pending(monkeypatch):
    ticket = _ticket(status="open")
    _patch_save(monkeypatch)

    _run(SupportService()._append(
        ticket, body="looking into it", author_is_admin=True,
        author_name="Support", new_status="pending",
    ))

    assert ticket.status == "pending"
    assert ticket.messages[-1].author_is_admin is True


def test_admin_reply_does_not_reopen_a_resolved_ticket(monkeypatch):
    """A closing remark on a resolved ticket must not drag it back into the
    open queue — reply_as_admin leaves the status alone once resolved."""
    ticket = _ticket(status="resolved", messages=[_msg(False), _msg(True)])
    _patch_save(monkeypatch)
    _patch_get(monkeypatch, ticket)

    _run(SupportService().reply_as_admin(_Admin(), "id", "one more thing"))

    assert ticket.status == "resolved"
    assert ticket.messages[-1].body == "one more thing"


def test_admin_reply_to_an_open_ticket_sets_pending(monkeypatch):
    """The same path, but from 'open' — here the status must move, so the
    ticket leaves the "needs a reply" queue."""
    ticket = _ticket(status="open")
    _patch_save(monkeypatch)
    _patch_get(monkeypatch, ticket)

    _run(SupportService().reply_as_admin(_Admin(), "id", "on it"))

    assert ticket.status == "pending"


def test_player_reply_reopens_a_resolved_ticket(monkeypatch):
    """The player disagreeing that it is resolved must bring it back —
    otherwise the thread is buried with nobody watching it."""
    ticket = _ticket(status="resolved", messages=[_msg(True)])
    _patch_save(monkeypatch)

    _run(SupportService()._append(
        ticket, body="still broken", author_is_admin=False,
        author_name="Player", new_status="open",
    ))

    assert ticket.status == "open"
    assert _awaiting_admin(ticket) is True


# ── closed tickets ────────────────────────────────────────────────────────────

def test_closed_ticket_rejects_new_messages(monkeypatch):
    ticket = _ticket(status="closed")
    _patch_save(monkeypatch)

    with pytest.raises(BadRequestException):
        _run(SupportService()._append(
            ticket, body="hello?", author_is_admin=False,
            author_name="Player", new_status="open",
        ))

    assert len(ticket.messages) == 1, "the message must not be recorded"


# ── activity timestamp ────────────────────────────────────────────────────────

def test_reply_bumps_last_activity(monkeypatch):
    """The inbox sorts on last_activity_at, so a reply that leaves it stale
    would sink the ticket that just got a response."""
    ticket = _ticket()
    stale = datetime.now(timezone.utc) - timedelta(days=3)
    object.__setattr__(ticket, "last_activity_at", stale)
    _patch_save(monkeypatch)

    _run(SupportService()._append(
        ticket, body="update", author_is_admin=True,
        author_name="Support", new_status="pending",
    ))

    assert ticket.last_activity_at > stale

"""
Regression tests for the forgot-password OTP flow.

These exist because the endpoint once accepted a reset with no proof the
caller held the code: the request schema had no `otp` field at all, and the
handler consumed *any* unexpired reset token for the address. Knowing an
email was therefore enough to take over an account — request a reset, then
immediately complete it. The tests below pin the two properties that close
that hole.

Run standalone (the repo's tests/conftest.py is legacy SQLAlchemy and would
otherwise fail collection):
    ./.venv/Scripts/python.exe -m pytest tests/unit/modules/test_password_reset_otp.py --noconftest
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

import pytest

from app.exceptions.errors import BadRequestException
from app.modules.auth import compat_router as auth_compat


def _run(coro):
    return asyncio.run(coro)


class _FakeToken:
    """Stands in for an OTPToken document; records whether it was deleted."""

    def __init__(self, code: str, *, expired: bool = False):
        self.code = code
        self.purpose = "reset_password"
        self.deleted = False
        self.expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=-1 if expired else 15
        )

    @property
    def is_expired(self) -> bool:
        return datetime.now(timezone.utc) > self.expires_at

    async def delete(self):
        self.deleted = True


class _FakeUser:
    id = "user-1"
    email = "victim@example.com"


class _Field:
    """Stands in for a Beanie class-level field, which cannot be compared
    outside an initialised DB. `field == value` yields (name, value), so the
    stubbed find_one sees exactly the filter the code under test built."""

    def __init__(self, name: str):
        self.name = name

    def __eq__(self, other):  # type: ignore[override]
        return (self.name, other)


def _patch_otp_token(monkeypatch, stored: _FakeToken | None):
    """Replace OTPToken with a stub whose find_one honours the code filter.

    The lookup returns the stored token only when the query's `code` equals
    it — i.e. it models the database faithfully on the one dimension that
    matters here: a query for the wrong code finds nothing.
    """

    class _StubOTPToken:
        user_id = _Field("user_id")
        code = _Field("code")
        purpose = _Field("purpose")

        @staticmethod
        async def find_one(*conditions):
            query = dict(conditions)
            if stored is None:
                return None
            return stored if query.get("code") == stored.code else None

    monkeypatch.setattr(auth_compat, "OTPToken", _StubOTPToken)


def _peek(monkeypatch, stored, submitted):
    """Run _validate_otp_peek with `submitted`, against `stored`."""
    _patch_otp_token(monkeypatch, stored)
    return _run(auth_compat._validate_otp_peek(_FakeUser(), submitted, "reset_password"))


# ── the schema must carry the code ────────────────────────────────────────────

def test_change_password_request_requires_otp():
    """Without an `otp` field the handler cannot check anything: Pydantic
    drops unknown keys, so a client sending one would be silently ignored."""
    fields = auth_compat.FlutterChangePasswordRequest.model_fields
    assert "otp" in fields, "change-password must accept the OTP"
    assert fields["otp"].is_required(), "OTP must be mandatory, not optional"


def test_the_permissive_consume_helper_is_gone():
    """The old helper deleted any valid token regardless of the submitted
    code. Keeping it around invites a future caller to reintroduce the bug."""
    assert not hasattr(auth_compat, "_consume_any_valid_reset_otp")


# ── the code itself must match ────────────────────────────────────────────────

def test_correct_code_is_accepted(monkeypatch):
    stored = _FakeToken("123456")
    token = _peek(monkeypatch, stored, "123456")
    assert token is stored


def test_wrong_code_is_rejected(monkeypatch):
    """The attack: a valid token exists (the victim requested a reset), but
    the caller does not know it. This must fail rather than consume it."""
    stored = _FakeToken("123456")

    with pytest.raises(BadRequestException):
        _peek(monkeypatch, stored, "000000")

    assert not stored.deleted, "a failed attempt must not burn the real token"


def test_no_token_at_all_is_rejected(monkeypatch):
    with pytest.raises(BadRequestException):
        _peek(monkeypatch, None, "123456")


def test_expired_code_is_rejected_and_cleared(monkeypatch):
    stored = _FakeToken("123456", expired=True)

    with pytest.raises(BadRequestException):
        _peek(monkeypatch, stored, "123456")

    assert stored.deleted, "an expired token should not linger"


# ── consumption ───────────────────────────────────────────────────────────────

def test_correct_code_is_consumed_once(monkeypatch):
    """A reset code is single-use: the token is deleted on success so the
    same code cannot reset the password twice."""
    stored = _FakeToken("123456")
    _patch_otp_token(monkeypatch, stored)

    _run(auth_compat._validate_and_consume_otp(_FakeUser(), "123456", "reset_password"))

    assert stored.deleted

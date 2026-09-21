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
        self.failed_attempts = 0
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
    """Replace OTPToken (as seen by otp_guard) with an in-memory stand-in.

    The collection models the one atomic operation the guard relies on:
    `find_one_and_update` returns the user's OTP with its attempt counter
    incremented, or None when there is no OTP or its attempts are spent.
    """
    from app.modules.auth import otp_guard

    class _Coll:
        async def find_one_and_update(self, flt, update, sort=None, return_document=None):
            if stored is None or stored.deleted:
                return None
            if stored.failed_attempts >= otp_guard.MAX_OTP_ATTEMPTS:
                return None
            stored.failed_attempts += 1
            return {"_id": "tok", "failed_attempts": stored.failed_attempts}

        async def delete_many(self, flt):
            if stored is not None:
                stored.deleted = True

    class _StubOTPToken:
        @staticmethod
        def get_motor_collection():
            return _Coll()

        @staticmethod
        async def get(_id):
            return stored

    monkeypatch.setattr(otp_guard, "OTPToken", _StubOTPToken)


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


# ── brute-force cap (audit 2.1) ───────────────────────────────────────────────

def test_five_wrong_guesses_burn_the_code_even_for_the_right_answer(monkeypatch):
    """A 6-digit code must not be guessable by trying them all: after 5
    attempts the OTP is deleted, so even the correct code no longer works."""
    stored = _FakeToken("123456")
    _patch_otp_token(monkeypatch, stored)

    for guess in ("000001", "000002", "000003", "000004", "000005"):
        with pytest.raises(BadRequestException):
            _run(auth_compat._validate_otp_peek(_FakeUser(), guess, "reset_password"))

    assert stored.deleted, "the OTP must be deleted once its attempts are spent"
    with pytest.raises(BadRequestException):
        _run(auth_compat._validate_otp_peek(_FakeUser(), "123456", "reset_password"))


def test_the_right_code_still_works_within_the_attempt_budget(monkeypatch):
    stored = _FakeToken("123456")
    _patch_otp_token(monkeypatch, stored)

    for guess in ("000001", "000002", "000003", "000004"):
        with pytest.raises(BadRequestException):
            _run(auth_compat._validate_otp_peek(_FakeUser(), guess, "reset_password"))

    assert _run(auth_compat._validate_otp_peek(_FakeUser(), "123456", "reset_password")) is stored


def test_the_two_step_reset_flow_fits_in_the_budget(monkeypatch):
    """verify-forgot-password-otp (peek) then change-password (consume) each
    spend an attempt; a legitimate user must not be locked out by that."""
    stored = _FakeToken("123456")
    _patch_otp_token(monkeypatch, stored)

    _run(auth_compat._validate_otp_peek(_FakeUser(), "123456", "reset_password"))
    _run(auth_compat._validate_and_consume_otp(_FakeUser(), "123456", "reset_password"))
    assert stored.deleted


def test_otp_codes_are_never_written_to_the_logs():
    import inspect

    from app.modules.auth import service as auth_service
    from app.utils import email as email_util

    assert "code=%s" not in inspect.getsource(auth_service.AuthService._create_and_send_otp)
    src = inspect.getsource(email_util.send_otp_email)
    assert "settings.DEBUG and not settings.SMTP_HOST" in src, "OTP log must be dev-only"

"""Arik QA item 12: public leagues get an invitation code too."""
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pymongo.errors import DuplicateKeyError

from app.exceptions.errors import RateLimitException
from app.modules.leagues import service as svc


def _fake_league(insert_side_effect):
    created = []

    def factory(**kw):
        obj = MagicMock(**{k: v for k, v in kw.items() if k != "invite_code"})
        obj.invite_code = kw["invite_code"]
        obj.insert = AsyncMock(side_effect=insert_side_effect.pop(0) if insert_side_effect else None,
                               return_value=obj)
        created.append(obj)
        return obj

    fake = MagicMock(side_effect=factory)
    fake.generate_invite_code = MagicMock(side_effect=["AAAA1111", "BBBB2222", "CCCC3333"])
    return fake, created


def test_a_public_league_is_created_with_a_code():
    fake, created = _fake_league([None])
    with patch.object(svc, "League", fake):
        league = asyncio.run(svc._insert_with_invite_code(name="x", type="public"))
    assert league.invite_code == "AAAA1111"


def test_a_code_collision_tries_another_code():
    fake, created = _fake_league([DuplicateKeyError("dup"), None])
    with patch.object(svc, "League", fake):
        league = asyncio.run(svc._insert_with_invite_code(name="x", type="public"))
    assert league.invite_code == "BBBB2222" and len(created) == 2


def test_guessing_codes_is_rate_limited():
    with patch("app.core.rate_limit.hit", AsyncMock(side_effect=RateLimitException("slow"))):
        with pytest.raises(RateLimitException):
            asyncio.run(svc._limit_code_attempts(MagicMock(id="U")))

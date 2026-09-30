"""QA 28/09 #5: the chosen jersey is stored on the account."""
from __future__ import annotations

import asyncio
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.modules.users import profile_router as pr


@pytest.mark.parametrize("bad", [-1, 6, 99])
def test_out_of_range_jersey_is_rejected(bad):
    with pytest.raises(ValidationError):
        pr.JerseyPayload(jersey_index=bad)


def test_get_clamps_a_stale_value():
    user = SimpleNamespace(jersey_index=42)
    assert asyncio.run(pr.get_jersey(user)).jersey_index == 0


def test_set_persists_on_the_user():
    saved = {}

    class _User:
        async def save_updated(self, **kw):
            saved.update(kw)

    out = asyncio.run(pr.set_jersey(pr.JerseyPayload(jersey_index=3), _User()))
    assert saved == {"jersey_index": 3} and out.jersey_index == 3

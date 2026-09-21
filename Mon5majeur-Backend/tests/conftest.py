"""Shared pytest fixtures.

The app is MongoDB/Beanie based. Unit tests stub their data sources (see
tests/unit/modules/test_retention_analytics.py); the `client` fixture below
talks to the ASGI app WITHOUT running its lifespan, so no database is needed
and only endpoints that answer before touching the DB (health, auth guards)
can be exercised through it. Anything that needs real data belongs in a unit
test with stubbed queries.
"""
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac


@pytest.fixture(autouse=True)
def _no_rate_limit(request, monkeypatch):
    """The auth throttles need Mongo; unit tests run without it, so make them
    no-ops. Tests of the limiter itself opt out with @pytest.mark.real_rate_limit."""
    if request.node.get_closest_marker("real_rate_limit"):
        return

    async def _noop(*args, **kwargs):
        return None

    from app.core import rate_limit

    for name in ("hit", "check_lockout", "record_failure", "clear_failures"):
        monkeypatch.setattr(rate_limit, name, _noop)

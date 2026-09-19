"""Shared pytest fixtures.

The app is MongoDB/Beanie based. Unit tests stub their data sources (see
tests/unit/modules/test_retention_analytics.py); the `client` fixture below
talks to the ASGI app WITHOUT running its lifespan, so no database is needed
and only endpoints that answer before touching the DB (health, auth guards)
can be exercised through it. Anything that needs real data belongs in a unit
test with stubbed queries.
"""
from typing import AsyncGenerator

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac

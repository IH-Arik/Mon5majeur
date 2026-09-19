"""API smoke tests that need no database (the ASGI app runs without its
lifespan - see tests/conftest.py). Registration/login flows against real data
were removed: they targeted a Postgres-era API that no longer exists."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_get_me_unauthorized(client: AsyncClient):
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_score_endpoints_require_auth(client: AsyncClient):
    """The paywalled match endpoints must never answer an anonymous caller."""
    for path in (
        "/api/private-leagues/matches/my-matches-today/",
        "/api/private-leagues/matches/1/1/",
        "/api/public-leagues/matches/1/1/",
        "/api/private-leagues/1/playoffs/",
    ):
        r = await client.get(path)
        assert r.status_code in (401, 403), (path, r.status_code)

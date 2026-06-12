import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_register_user(client: AsyncClient):
    payload = {"email": "integration@example.com", "password": "password123"}
    response = await client.post("/api/v1/users", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == payload["email"]
    assert "id" in data


@pytest.mark.asyncio
async def test_login(client: AsyncClient):
    # Register first
    await client.post("/api/v1/users", json={"email": "login_test@example.com", "password": "password123"})

    response = await client.post("/api/v1/auth/login", json={"email": "login_test@example.com", "password": "password123"})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data


@pytest.mark.asyncio
async def test_get_me_unauthorized(client: AsyncClient):
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_get_me_authorized(client: AsyncClient):
    await client.post("/api/v1/users", json={"email": "me_test@example.com", "password": "password123"})
    login = await client.post("/api/v1/auth/login", json={"email": "me_test@example.com", "password": "password123"})
    token = login.json()["access_token"]

    response = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["email"] == "me_test@example.com"

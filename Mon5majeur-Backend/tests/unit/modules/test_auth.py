import pytest
from unittest.mock import AsyncMock, MagicMock

from app.core.security import hash_password
from app.exceptions.errors import UnauthorizedException
from app.modules.auth.schema import LoginRequest
from app.modules.auth.service import AuthService
from app.modules.users.model import User


@pytest.fixture
def mock_user():
    user = MagicMock(spec=User)
    user.id = "00000000-0000-0000-0000-000000000001"
    user.email = "test@example.com"
    user.hashed_password = hash_password("secret123")
    user.is_active = True
    return user


@pytest.fixture
def mock_user_repo(mock_user):
    repo = AsyncMock()
    repo.get_by_email.return_value = mock_user
    return repo


@pytest.mark.asyncio
async def test_login_success(mock_user_repo):
    service = AuthService(mock_user_repo)
    result = await service.login(LoginRequest(email="test@example.com", password="secret123"))
    assert result.access_token
    assert result.refresh_token
    assert result.token_type == "bearer"


@pytest.mark.asyncio
async def test_login_wrong_password(mock_user_repo):
    service = AuthService(mock_user_repo)
    with pytest.raises(UnauthorizedException):
        await service.login(LoginRequest(email="test@example.com", password="wrong"))


@pytest.mark.asyncio
async def test_login_user_not_found(mock_user_repo):
    mock_user_repo.get_by_email.return_value = None
    service = AuthService(mock_user_repo)
    with pytest.raises(UnauthorizedException):
        await service.login(LoginRequest(email="nobody@example.com", password="anything"))

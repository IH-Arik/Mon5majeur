import pytest
from unittest.mock import AsyncMock

from app.exceptions.errors import AlreadyExistsException
from app.modules.users.schema import UserCreate
from app.modules.users.service import UserService


@pytest.fixture
def mock_user_repo():
    repo = AsyncMock()
    repo.email_exists.return_value = False
    repo.create.return_value = AsyncMock(id="uuid-1", email="new@example.com", full_name=None, is_active=True, is_superuser=False, is_verified=False, avatar_url=None)
    return repo


@pytest.mark.asyncio
async def test_create_user_success(mock_user_repo):
    service = UserService(mock_user_repo)
    user = await service.create_user(UserCreate(email="new@example.com", password="secure123"))
    mock_user_repo.create.assert_called_once()
    assert user.email == "new@example.com"


@pytest.mark.asyncio
async def test_create_user_duplicate_email(mock_user_repo):
    mock_user_repo.email_exists.return_value = True
    service = UserService(mock_user_repo)
    with pytest.raises(AlreadyExistsException):
        await service.create_user(UserCreate(email="existing@example.com", password="secure123"))

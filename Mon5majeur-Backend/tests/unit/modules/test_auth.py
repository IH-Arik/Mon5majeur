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


# ── Google OAuth Tests ────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_google_oauth_new_user(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import GoogleOAuthRequest

    mock_user_repo.get_by_google_id.return_value = None
    mock_user_repo.get_by_email.return_value = None
    new_user = MagicMock(spec=User)
    new_user.id = "00000000-0000-0000-0000-000000000002"
    new_user.email = "googleuser@example.com"
    new_user.auto_id = 42
    new_user.full_name = "Google Tester"
    new_user.avatar_url = "https://example.com/photo.jpg"
    new_user.is_profile_complete = False
    mock_user_repo.create.return_value = new_user

    tokeninfo_data = {
        "iss": "accounts.google.com",
        "sub": "google-sub-12345",
        "aud": "144976760248-ncr727numc3pgi5nlq1fqp6t0k28gitv.apps.googleusercontent.com",
        "email": "googleuser@example.com",
        "email_verified": "true",
        "name": "Google Tester",
        "picture": "https://example.com/photo.jpg",
    }

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = tokeninfo_data

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_resp
        service = AuthService(mock_user_repo)
        result = await service.google_oauth(GoogleOAuthRequest(id_token="valid-token"))

        assert result.access_token
        assert result.refresh_token
        assert result.access == result.access_token
        assert result.refresh == result.refresh_token
        assert result.user is not None
        assert result.user.email == "googleuser@example.com"
        assert result.user.id == 42
        assert result.user.full_name == "Google Tester"
        mock_user_repo.create.assert_called_once()


@pytest.mark.asyncio
async def test_google_oauth_existing_user_by_google_id(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import GoogleOAuthRequest

    existing_user = MagicMock(spec=User)
    existing_user.id = "00000000-0000-0000-0000-000000000001"
    existing_user.email = "existing@example.com"
    existing_user.google_id = "google-sub-999"
    existing_user.auto_id = 7
    existing_user.is_active = True
    existing_user.is_banned = False
    existing_user.full_name = "Existing User"
    existing_user.avatar_url = "https://example.com/avatar.png"
    existing_user.is_profile_complete = True
    existing_user.save_updated = AsyncMock()

    mock_user_repo.get_by_google_id.return_value = existing_user

    tokeninfo_data = {
        "iss": "https://accounts.google.com",
        "sub": "google-sub-999",
        "aud": "144976760248-t1l00leat9g0jvace3f6chksju0nlc2n.apps.googleusercontent.com",  # Android client ID
        "email": "existing@example.com",
        "email_verified": True,
        "name": "Existing User",
    }

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = tokeninfo_data

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_resp
        service = AuthService(mock_user_repo)
        result = await service.google_oauth(GoogleOAuthRequest(id_token="valid-token"))

        assert result.access_token
        assert result.user.id == 7
        mock_user_repo.create.assert_not_called()


@pytest.mark.asyncio
async def test_google_oauth_account_linking(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import GoogleOAuthRequest

    mock_user_repo.get_by_google_id.return_value = None
    email_user = MagicMock(spec=User)
    email_user.id = "00000000-0000-0000-0000-000000000003"
    email_user.email = "emailuser@example.com"
    email_user.google_id = None
    email_user.auto_id = 15
    email_user.is_active = True
    email_user.is_banned = False
    email_user.is_verified = False
    email_user.full_name = None
    email_user.avatar_url = None
    email_user.auth_provider = "email"
    email_user.hashed_password = "hashed_secret"
    email_user.save_updated = AsyncMock()

    mock_user_repo.get_by_email.return_value = email_user

    tokeninfo_data = {
        "iss": "accounts.google.com",
        "sub": "google-sub-555",
        "aud": "144976760248-m1k483v6kbi0o8i28l96b2pra777ppfk.apps.googleusercontent.com",  # iOS client ID
        "email": "emailuser@example.com",
        "email_verified": "true",
        "name": "Linked Name",
        "picture": "https://example.com/pic.jpg",
    }

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = tokeninfo_data

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_resp
        service = AuthService(mock_user_repo)
        result = await service.google_oauth(GoogleOAuthRequest(id_token="valid-token"))

        assert result.access_token
        email_user.save_updated.assert_called_once()
        call_kwargs = email_user.save_updated.call_args.kwargs
        assert call_kwargs.get("google_id") == "google-sub-555"
        assert call_kwargs.get("is_verified") is True
        assert call_kwargs.get("full_name") == "Linked Name"
        assert call_kwargs.get("avatar_url") == "https://example.com/pic.jpg"


@pytest.mark.asyncio
async def test_google_oauth_banned_user(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import GoogleOAuthRequest

    banned_user = MagicMock(spec=User)
    banned_user.id = "00000000-0000-0000-0000-000000000004"
    banned_user.email = "banned@example.com"
    banned_user.google_id = "google-sub-banned"
    banned_user.is_active = True
    banned_user.is_banned = True

    mock_user_repo.get_by_google_id.return_value = banned_user

    tokeninfo_data = {
        "iss": "accounts.google.com",
        "sub": "google-sub-banned",
        "aud": "144976760248-ncr727numc3pgi5nlq1fqp6t0k28gitv.apps.googleusercontent.com",
        "email": "banned@example.com",
        "email_verified": True,
    }

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = tokeninfo_data

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_resp
        service = AuthService(mock_user_repo)
        with pytest.raises(UnauthorizedException) as exc_info:
            await service.google_oauth(GoogleOAuthRequest(id_token="banned-token"))
        assert "banned" in str(exc_info.value.detail).lower()


@pytest.mark.asyncio
async def test_google_oauth_audience_mismatch(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import GoogleOAuthRequest

    tokeninfo_data = {
        "iss": "accounts.google.com",
        "sub": "google-sub-foreign",
        "aud": "some-unauthorized-client-id.apps.googleusercontent.com",
        "email": "foreign@example.com",
        "email_verified": True,
    }

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = tokeninfo_data

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_resp
        service = AuthService(mock_user_repo)
        with pytest.raises(UnauthorizedException) as exc_info:
            await service.google_oauth(GoogleOAuthRequest(id_token="token-with-wrong-aud"))
        assert "audience" in str(exc_info.value.detail).lower()


@pytest.mark.asyncio
async def test_google_oauth_invalid_token(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import GoogleOAuthRequest

    mock_resp = MagicMock()
    mock_resp.status_code = 400
    mock_resp.text = "Invalid Value"

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = mock_resp
        service = AuthService(mock_user_repo)
        with pytest.raises(UnauthorizedException) as exc_info:
            await service.google_oauth(GoogleOAuthRequest(id_token="bad-token"))
        assert "invalid" in str(exc_info.value.detail).lower()

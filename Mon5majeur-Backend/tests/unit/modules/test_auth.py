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


# ── Apple OAuth Tests ─────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_apple_oauth_new_user_with_email(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import AppleOAuthRequest

    mock_user_repo.get_by_apple_id.return_value = None
    mock_user_repo.get_by_email.return_value = None

    new_user = MagicMock(spec=User)
    new_user.id = "00000000-0000-0000-0000-000000000010"
    new_user.email = "appleuser@privaterelay.apple.com"
    new_user.auto_id = 100
    new_user.full_name = "Apple Tester"
    new_user.avatar_url = None
    new_user.is_profile_complete = False
    mock_user_repo.create.return_value = new_user

    claims = {
        "iss": "https://appleid.apple.com",
        "sub": "apple-sub-001",
        "email": "appleuser@privaterelay.apple.com",
    }

    with patch("jose.jwt.get_unverified_claims", return_value=claims):
        service = AuthService(mock_user_repo)
        result = await service.apple_oauth(
            AppleOAuthRequest(
                identity_token="valid-apple-token",
                full_name="Apple Tester",
                email="appleuser@privaterelay.apple.com",
            )
        )

        assert result.access_token
        assert result.refresh_token
        assert result.user.id == 100
        assert result.user.email == "appleuser@privaterelay.apple.com"
        mock_user_repo.create.assert_called_once()
        create_kwargs = mock_user_repo.create.call_args.kwargs
        assert create_kwargs["email"] == "appleuser@privaterelay.apple.com"
        assert create_kwargs["apple_id"] == "apple-sub-001"
        assert create_kwargs["auth_provider"] == "apple"


@pytest.mark.asyncio
async def test_apple_oauth_returning_user_without_email(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import AppleOAuthRequest

    existing_user = MagicMock(spec=User)
    existing_user.id = "00000000-0000-0000-0000-000000000011"
    existing_user.email = "returning@privaterelay.apple.com"
    existing_user.apple_id = "apple-sub-returning"
    existing_user.auto_id = 101
    existing_user.is_active = True
    existing_user.is_banned = False
    existing_user.full_name = "Returning User"
    existing_user.avatar_url = None
    existing_user.is_profile_complete = True
    existing_user.save_updated = AsyncMock()

    mock_user_repo.get_by_apple_id.return_value = existing_user

    # Apple does NOT send email on subsequent logins!
    claims = {
        "iss": "https://appleid.apple.com",
        "sub": "apple-sub-returning",
    }

    with patch("jose.jwt.get_unverified_claims", return_value=claims):
        service = AuthService(mock_user_repo)
        result = await service.apple_oauth(
            AppleOAuthRequest(
                identity_token="subsequent-apple-token",
                full_name=None,
                email=None,
            )
        )

        assert result.access_token
        assert result.user.id == 101
        assert result.user.email == "returning@privaterelay.apple.com"
        mock_user_repo.create.assert_not_called()


@pytest.mark.asyncio
async def test_apple_oauth_new_user_null_email_fallback(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import AppleOAuthRequest

    mock_user_repo.get_by_apple_id.return_value = None
    mock_user_repo.get_by_email.return_value = None

    new_user = MagicMock(spec=User)
    new_user.id = "00000000-0000-0000-0000-000000000012"
    new_user.email = "apple_01234567890123456789@privaterelay.apple.com"
    new_user.auto_id = 102
    new_user.full_name = "Apple User"
    new_user.avatar_url = None
    new_user.is_profile_complete = False
    mock_user_repo.create.return_value = new_user

    claims = {
        "iss": "https://appleid.apple.com",
        "sub": "01234567890123456789extra_chars",
    }

    with patch("jose.jwt.get_unverified_claims", return_value=claims):
        service = AuthService(mock_user_repo)
        result = await service.apple_oauth(
            AppleOAuthRequest(
                identity_token="no-email-token",
                full_name=None,
                email=None,
            )
        )

        assert result.access_token
        mock_user_repo.create.assert_called_once()
        create_kwargs = mock_user_repo.create.call_args.kwargs
        assert "privaterelay.apple.com" in create_kwargs["email"]
        assert create_kwargs["apple_id"] == "01234567890123456789extra_chars"


@pytest.mark.asyncio
async def test_apple_oauth_account_linking(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import AppleOAuthRequest

    mock_user_repo.get_by_apple_id.return_value = None

    existing_email_user = MagicMock(spec=User)
    existing_email_user.id = "00000000-0000-0000-0000-000000000013"
    existing_email_user.email = "existing@example.com"
    existing_email_user.apple_id = None
    existing_email_user.auto_id = 103
    existing_email_user.is_active = True
    existing_email_user.is_banned = False
    existing_email_user.is_verified = False
    existing_email_user.full_name = None
    existing_email_user.avatar_url = None
    existing_email_user.auth_provider = "email"
    existing_email_user.hashed_password = "hashed"
    existing_email_user.save_updated = AsyncMock()

    mock_user_repo.get_by_email.return_value = existing_email_user

    claims = {
        "iss": "https://appleid.apple.com",
        "sub": "apple-sub-link",
        "email": "existing@example.com",
    }

    with patch("jose.jwt.get_unverified_claims", return_value=claims):
        service = AuthService(mock_user_repo)
        result = await service.apple_oauth(
            AppleOAuthRequest(
                identity_token="link-apple-token",
                full_name="Linked Apple User",
                email="existing@example.com",
            )
        )

        assert result.access_token
        existing_email_user.save_updated.assert_called_once()
        call_kwargs = existing_email_user.save_updated.call_args.kwargs
        assert call_kwargs.get("apple_id") == "apple-sub-link"
        assert call_kwargs.get("is_verified") is True
        assert call_kwargs.get("full_name") == "Linked Apple User"


@pytest.mark.asyncio
async def test_apple_oauth_banned_user(mock_user_repo):
    from unittest.mock import patch
    from app.modules.auth.schema import AppleOAuthRequest

    banned_user = MagicMock(spec=User)
    banned_user.id = "00000000-0000-0000-0000-000000000014"
    banned_user.email = "banned@example.com"
    banned_user.apple_id = "apple-sub-banned"
    banned_user.is_active = True
    banned_user.is_banned = True

    mock_user_repo.get_by_apple_id.return_value = banned_user

    claims = {
        "iss": "https://appleid.apple.com",
        "sub": "apple-sub-banned",
    }

    with patch("jose.jwt.get_unverified_claims", return_value=claims):
        service = AuthService(mock_user_repo)
        with pytest.raises(UnauthorizedException) as exc_info:
            await service.apple_oauth(
                AppleOAuthRequest(identity_token="token-banned")
            )
        assert "banned" in str(exc_info.value.detail).lower()


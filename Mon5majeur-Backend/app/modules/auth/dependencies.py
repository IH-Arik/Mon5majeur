from beanie import PydanticObjectId
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError

from app.core.security import decode_token
from app.exceptions.errors import ForbiddenException, UnauthorizedException
from app.modules.auth.constants import TOKEN_URL
from app.modules.users.model import User
from app.modules.users.repository import UserRepository

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=TOKEN_URL)


async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise UnauthorizedException("Invalid token type")
        user_id = payload.get("sub")
        if not user_id:
            raise UnauthorizedException()
    except JWTError:
        raise UnauthorizedException("Could not validate credentials")

    user = await UserRepository().get(PydanticObjectId(user_id))
    if user is None:
        raise UnauthorizedException("User not found")
    if not user.is_active:
        raise ForbiddenException("Inactive user")
    return user


# Alias used inside auth router to avoid circular import
get_current_user_for_auth = get_current_user


async def get_current_superuser(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_superuser:
        raise ForbiddenException("Superuser privileges required")
    return current_user


def get_auth_service():
    from app.modules.auth.service import AuthService
    return AuthService(UserRepository())

import re

from app.database.counters import next_seq
from app.modules.users.model import User
from app.shared.base_repository import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self) -> None:
        super().__init__(User)

    async def create(self, **kwargs) -> User:  # type: ignore[override]
        user = User(**kwargs)
        await user.insert()
        user.auto_id = await next_seq("users")
        await user.save()
        return user

    async def get_by_email(self, email: str) -> User | None:
        """Case-insensitive. Phone keyboards capitalise the first letter, and
        EmailStr only lowercases the domain, so "Name@x.com" used to miss the
        account stored as "name@x.com" (QA 30/09 #8 #1: the first login attempt
        failed, the retyped one worked). Exact matches go first so the common
        case still uses the index; the regex is only the fallback."""
        email = email.strip()
        for candidate in dict.fromkeys((email, email.lower())):
            user = await User.find_one(User.email == candidate)
            if user:
                return user
        return await self._email_ignoring_case(email)

    @staticmethod
    async def _email_ignoring_case(email: str) -> User | None:
        return await User.find_one(
            {"email": {"$regex": f"^{re.escape(email)}$", "$options": "i"}}
        )

    async def email_exists(self, email: str) -> bool:
        return await self.get_by_email(email) is not None

    async def get_by_google_id(self, google_id: str) -> User | None:
        return await User.find_one(User.google_id == google_id)

    async def get_by_apple_id(self, apple_id: str) -> User | None:
        return await User.find_one(User.apple_id == apple_id)

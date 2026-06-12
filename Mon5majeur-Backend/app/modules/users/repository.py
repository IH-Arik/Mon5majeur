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
        return await User.find_one(User.email == email)

    async def email_exists(self, email: str) -> bool:
        return await User.find_one(User.email == email) is not None

    async def get_by_google_id(self, google_id: str) -> User | None:
        return await User.find_one(User.google_id == google_id)

    async def get_by_apple_id(self, apple_id: str) -> User | None:
        return await User.find_one(User.apple_id == apple_id)

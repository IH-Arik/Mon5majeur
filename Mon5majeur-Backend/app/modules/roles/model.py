from beanie import Indexed
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class Role(BaseDocument):
    name: Indexed(str, unique=True)  # type: ignore[valid-type]
    description: str | None = None
    is_system: bool = False

    class Settings:
        name = "roles"
        indexes = [
            IndexModel([("name", ASCENDING)], unique=True),
        ]

from beanie import Indexed
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class Permission(BaseDocument):
    name: str
    codename: Indexed(str, unique=True)  # type: ignore[valid-type]
    description: str | None = None
    resource: str
    action: str

    class Settings:
        name = "permissions"
        indexes = [
            IndexModel([("codename", ASCENDING)], unique=True),
        ]

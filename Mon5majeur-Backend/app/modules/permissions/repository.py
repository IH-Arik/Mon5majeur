from app.modules.permissions.model import Permission
from app.shared.base_repository import BaseRepository


class PermissionRepository(BaseRepository[Permission]):
    def __init__(self) -> None:
        super().__init__(Permission)

    async def get_by_codename(self, codename: str) -> Permission | None:
        return await Permission.find_one(Permission.codename == codename)

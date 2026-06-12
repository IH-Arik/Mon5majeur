from app.modules.roles.model import Role
from app.shared.base_repository import BaseRepository


class RoleRepository(BaseRepository[Role]):
    def __init__(self) -> None:
        super().__init__(Role)

    async def get_by_name(self, name: str) -> Role | None:
        return await Role.find_one(Role.name == name)

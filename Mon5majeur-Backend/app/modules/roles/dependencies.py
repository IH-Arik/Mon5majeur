from app.modules.roles.repository import RoleRepository
from app.modules.roles.service import RoleService


def get_role_service() -> RoleService:
    return RoleService(RoleRepository())

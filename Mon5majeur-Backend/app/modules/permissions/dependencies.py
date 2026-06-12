from app.modules.permissions.repository import PermissionRepository
from app.modules.permissions.service import PermissionService


def get_permission_service() -> PermissionService:
    return PermissionService(PermissionRepository())

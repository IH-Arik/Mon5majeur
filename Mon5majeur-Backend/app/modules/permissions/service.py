import uuid

from app.exceptions.errors import AlreadyExistsException, NotFoundException
from app.modules.permissions.model import Permission
from app.modules.permissions.repository import PermissionRepository
from app.modules.permissions.schema import PermissionCreate
from app.shared.pagination import Page, PaginationParams


class PermissionService:
    def __init__(self, repo: PermissionRepository) -> None:
        self.repo = repo

    async def create_permission(self, payload: PermissionCreate) -> Permission:
        if await self.repo.get_by_codename(payload.codename):
            raise AlreadyExistsException(f"Permission '{payload.codename}' already exists")
        return await self.repo.create(**payload.model_dump())

    async def get_permission(self, permission_id: uuid.UUID) -> Permission:
        perm = await self.repo.get(permission_id)
        if not perm:
            raise NotFoundException("Permission not found")
        return perm

    async def list_permissions(self, params: PaginationParams) -> Page[Permission]:
        items, total = await self.repo.list(offset=params.offset, limit=params.limit)
        return Page.create(items, total, params)

    async def delete_permission(self, permission_id: uuid.UUID) -> None:
        perm = await self.get_permission(permission_id)
        await self.repo.delete(perm)

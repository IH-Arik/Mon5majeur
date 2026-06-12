import uuid

from app.exceptions.errors import AlreadyExistsException, BadRequestException, NotFoundException
from app.modules.roles.model import Role
from app.modules.roles.repository import RoleRepository
from app.modules.roles.schema import RoleCreate, RoleUpdate
from app.shared.pagination import Page, PaginationParams


class RoleService:
    def __init__(self, repo: RoleRepository) -> None:
        self.repo = repo

    async def create_role(self, payload: RoleCreate) -> Role:
        if await self.repo.get_by_name(payload.name):
            raise AlreadyExistsException(f"Role '{payload.name}' already exists")
        return await self.repo.create(**payload.model_dump())

    async def get_role(self, role_id: uuid.UUID) -> Role:
        role = await self.repo.get(role_id)
        if not role:
            raise NotFoundException("Role not found")
        return role

    async def list_roles(self, params: PaginationParams) -> Page[Role]:
        items, total = await self.repo.list(offset=params.offset, limit=params.limit)
        return Page.create(items, total, params)

    async def update_role(self, role_id: uuid.UUID, payload: RoleUpdate) -> Role:
        role = await self.get_role(role_id)
        if role.is_system:
            raise BadRequestException("Cannot modify system roles")
        return await self.repo.update(role, **payload.model_dump(exclude_unset=True))

    async def delete_role(self, role_id: uuid.UUID) -> None:
        role = await self.get_role(role_id)
        if role.is_system:
            raise BadRequestException("Cannot delete system roles")
        await self.repo.delete(role)

import uuid

from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_current_superuser
from app.modules.roles.dependencies import get_role_service
from app.modules.roles.model import Role
from app.modules.roles.schema import RoleCreate, RoleResponse, RoleUpdate
from app.modules.roles.service import RoleService
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/roles", tags=["Roles"], dependencies=[Depends(get_current_superuser)])


@router.post("", response_model=RoleResponse, status_code=status.HTTP_201_CREATED)
async def create_role(payload: RoleCreate, service: RoleService = Depends(get_role_service)) -> Role:
    return await service.create_role(payload)


@router.get("", response_model=Page[RoleResponse])
async def list_roles(params: PaginationParams = Depends(), service: RoleService = Depends(get_role_service)) -> Page[Role]:
    return await service.list_roles(params)


@router.get("/{role_id}", response_model=RoleResponse)
async def get_role(role_id: uuid.UUID, service: RoleService = Depends(get_role_service)) -> Role:
    return await service.get_role(role_id)


@router.patch("/{role_id}", response_model=RoleResponse)
async def update_role(role_id: uuid.UUID, payload: RoleUpdate, service: RoleService = Depends(get_role_service)) -> Role:
    return await service.update_role(role_id, payload)


@router.delete("/{role_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_role(role_id: uuid.UUID, service: RoleService = Depends(get_role_service)) -> None:
    await service.delete_role(role_id)

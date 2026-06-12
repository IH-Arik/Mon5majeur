import uuid

from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_current_superuser
from app.modules.permissions.dependencies import get_permission_service
from app.modules.permissions.model import Permission
from app.modules.permissions.schema import PermissionCreate, PermissionResponse
from app.modules.permissions.service import PermissionService
from app.shared.pagination import Page, PaginationParams

router = APIRouter(prefix="/permissions", tags=["Permissions"], dependencies=[Depends(get_current_superuser)])


@router.post("", response_model=PermissionResponse, status_code=status.HTTP_201_CREATED)
async def create_permission(payload: PermissionCreate, service: PermissionService = Depends(get_permission_service)) -> Permission:
    return await service.create_permission(payload)


@router.get("", response_model=Page[PermissionResponse])
async def list_permissions(params: PaginationParams = Depends(), service: PermissionService = Depends(get_permission_service)) -> Page[Permission]:
    return await service.list_permissions(params)


@router.get("/{permission_id}", response_model=PermissionResponse)
async def get_permission(permission_id: uuid.UUID, service: PermissionService = Depends(get_permission_service)) -> Permission:
    return await service.get_permission(permission_id)


@router.delete("/{permission_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_permission(permission_id: uuid.UUID, service: PermissionService = Depends(get_permission_service)) -> None:
    await service.delete_permission(permission_id)

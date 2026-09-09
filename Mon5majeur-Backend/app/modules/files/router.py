from beanie import PydanticObjectId
from fastapi import APIRouter, BackgroundTasks, Depends, UploadFile, status

from app.modules.auth.dependencies import get_current_user
from app.modules.files.dependencies import get_file_service
from app.modules.files.model import UploadedFile
from app.modules.files.schema import FileResponse
from app.modules.files.service import FileService
from app.modules.users.model import User

router = APIRouter(prefix="/files", tags=["Files"])


@router.post("", response_model=FileResponse, status_code=status.HTTP_201_CREATED, summary="Upload a file")
async def upload_file(
    file: UploadFile,
    current_user: User = Depends(get_current_user),
    service: FileService = Depends(get_file_service),
) -> UploadedFile:
    return await service.upload(file, current_user.id)


@router.get("/{file_id}", response_model=FileResponse, summary="Get file metadata")
async def get_file(
    file_id: PydanticObjectId,
    current_user: User = Depends(get_current_user),
    service: FileService = Depends(get_file_service),
) -> UploadedFile:
    return await service.get_file(file_id)


@router.delete("/{file_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a file")
async def delete_file(
    file_id: PydanticObjectId,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    service: FileService = Depends(get_file_service),
) -> None:
    await service.delete_file(file_id)

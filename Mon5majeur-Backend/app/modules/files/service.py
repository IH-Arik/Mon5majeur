from beanie import PydanticObjectId
from pathlib import Path

from fastapi import UploadFile

from app.core.config import settings
from app.exceptions.errors import BadRequestException, NotFoundException
from app.modules.files.model import UploadedFile
from app.modules.files.repository import FileRepository
from app.utils.storage import save_file, delete_file


class FileService:
    def __init__(self, repo: FileRepository) -> None:
        self.repo = repo

    async def upload(self, file: UploadFile, uploader_id: PydanticObjectId) -> UploadedFile:
        ext = Path(file.filename or "").suffix.lstrip(".").lower()
        if ext not in settings.ALLOWED_UPLOAD_EXTENSIONS:
            raise BadRequestException(f"File type '.{ext}' not allowed")

        content = await file.read()
        if len(content) > settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024:
            raise BadRequestException(f"File exceeds {settings.MAX_UPLOAD_SIZE_MB}MB limit")

        stored_name, storage_path, public_url = await save_file(content, file.filename or "upload", ext)

        return await self.repo.create(
            uploader_id=uploader_id,
            original_filename=file.filename or "upload",
            stored_filename=stored_name,
            content_type=file.content_type or "application/octet-stream",
            size_bytes=len(content),
            storage_path=storage_path,
            public_url=public_url,
        )

    async def get_file(self, file_id: PydanticObjectId) -> UploadedFile:
        f = await self.repo.get(file_id)
        if not f:
            raise NotFoundException("File not found")
        return f

    async def delete_file(self, file_id: PydanticObjectId) -> None:
        f = await self.get_file(file_id)
        await delete_file(f.stored_filename)
        await self.repo.delete(f)

from beanie import PydanticObjectId
from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument


class UploadedFile(BaseDocument):
    uploader_id: PydanticObjectId | None = None
    original_filename: str
    stored_filename: str
    content_type: str
    size_bytes: int
    storage_path: str
    public_url: str | None = None

    class Settings:
        name = "uploaded_files"
        indexes = [
            IndexModel([("uploader_id", ASCENDING)]),
        ]

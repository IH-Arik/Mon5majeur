import uuid

from app.shared.base_schema import BaseResponseSchema, BaseSchema


class FileResponse(BaseResponseSchema):
    uploader_id: uuid.UUID | None
    original_filename: str
    content_type: str
    size_bytes: int
    public_url: str | None

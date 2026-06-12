import uuid
from pathlib import Path

import aiofiles

from app.core.config import settings


async def save_file(content: bytes, original_name: str, ext: str) -> tuple[str, str, str | None]:
    upload_dir = Path(settings.UPLOAD_DIR)
    upload_dir.mkdir(parents=True, exist_ok=True)

    stored_name = f"{uuid.uuid4().hex}.{ext}"
    storage_path = str(upload_dir / stored_name)

    async with aiofiles.open(storage_path, "wb") as f:
        await f.write(content)

    public_url = f"/static/{stored_name}"
    return stored_name, storage_path, public_url


async def delete_file(stored_filename: str) -> None:
    path = Path(settings.UPLOAD_DIR) / stored_filename
    if path.exists():
        path.unlink()

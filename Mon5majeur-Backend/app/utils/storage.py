import uuid
from pathlib import Path

import aiofiles

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


async def save_file(content: bytes, original_name: str, ext: str) -> tuple[str, str, str | None]:
    # settings.UPLOAD_DIR is resolved to an absolute, project-root-anchored
    # path (see Settings.resolve_upload_dir) — never relative to whatever
    # the process's cwd happens to be at request time.
    upload_dir = Path(settings.UPLOAD_DIR)

    try:
        upload_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        logger.error("save_file: could not create upload dir %s", upload_dir, exc_info=True)
        raise

    stored_name = f"{uuid.uuid4().hex}.{ext}"
    storage_path = str(upload_dir / stored_name)

    try:
        async with aiofiles.open(storage_path, "wb") as f:
            await f.write(content)
    except OSError:
        # Logged with the exact path so a permissions/disk-space problem on
        # the server is visible in the logs instead of a bare 500 — this is
        # the step most likely to fail (read-only mount, wrong owner, full
        # disk), and the generic handler alone doesn't say which.
        logger.error(
            "save_file: could not write %s (original=%s, %d bytes)",
            storage_path, original_name, len(content), exc_info=True,
        )
        raise

    public_url = f"/static/{stored_name}"
    return stored_name, storage_path, public_url


async def delete_file(stored_filename: str) -> None:
    path = Path(settings.UPLOAD_DIR) / stored_filename
    if path.exists():
        path.unlink()

from app.modules.files.repository import FileRepository
from app.modules.files.service import FileService


def get_file_service() -> FileService:
    return FileService(FileRepository())

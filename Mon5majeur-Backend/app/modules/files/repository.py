from app.modules.files.model import UploadedFile
from app.shared.base_repository import BaseRepository


class FileRepository(BaseRepository[UploadedFile]):
    def __init__(self) -> None:
        super().__init__(UploadedFile)

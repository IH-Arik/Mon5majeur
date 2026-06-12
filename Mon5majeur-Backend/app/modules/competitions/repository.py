from beanie import PydanticObjectId

from app.modules.competitions.model import Competition, CompetitionEntry
from app.shared.base_repository import BaseRepository


class CompetitionRepository(BaseRepository[Competition]):
    def __init__(self) -> None:
        super().__init__(Competition)

    async def get_by_status(self, status: str, offset: int = 0, limit: int = 20) -> tuple[list[Competition], int]:
        query = Competition.find(Competition.status == status).sort(-Competition.start_date)
        total = await query.count()
        items = await query.skip(offset).limit(limit).to_list()
        return items, total


class CompetitionEntryRepository(BaseRepository[CompetitionEntry]):
    def __init__(self) -> None:
        super().__init__(CompetitionEntry)

    async def get_entry(self, competition_id: PydanticObjectId, user_id: PydanticObjectId) -> CompetitionEntry | None:
        return await CompetitionEntry.find_one(
            CompetitionEntry.competition_id == competition_id,
            CompetitionEntry.user_id == user_id,
        )

    async def get_leaderboard(self, competition_id: PydanticObjectId, offset: int = 0, limit: int = 50) -> list[CompetitionEntry]:
        return await CompetitionEntry.find(
            CompetitionEntry.competition_id == competition_id,
        ).sort(-CompetitionEntry.score).skip(offset).limit(limit).to_list()

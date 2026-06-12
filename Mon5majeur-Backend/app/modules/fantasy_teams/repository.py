from beanie import PydanticObjectId

from app.modules.fantasy_teams.model import FantasyTeam
from app.shared.base_repository import BaseRepository


class FantasyTeamRepository(BaseRepository[FantasyTeam]):
    def __init__(self) -> None:
        super().__init__(FantasyTeam)

    async def get_by_owner(self, owner_id: PydanticObjectId, offset: int = 0, limit: int = 20) -> tuple[list[FantasyTeam], int]:
        query = FantasyTeam.find(FantasyTeam.owner_id == owner_id)
        total = await query.count()
        items = await query.skip(offset).limit(limit).to_list()
        return items, total

    async def get_by_competition(self, competition_id: PydanticObjectId, offset: int = 0, limit: int = 20) -> tuple[list[FantasyTeam], int]:
        query = FantasyTeam.find(FantasyTeam.competition_id == competition_id).sort(-FantasyTeam.total_fantasy_score)
        total = await query.count()
        items = await query.skip(offset).limit(limit).to_list()
        return items, total

    async def count_by_owner(self, owner_id: PydanticObjectId) -> int:
        return await FantasyTeam.find(FantasyTeam.owner_id == owner_id).count()

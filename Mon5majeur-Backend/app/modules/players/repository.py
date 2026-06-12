from beanie import PydanticObjectId
from beanie.operators import RegEx

from app.modules.players.model import Player
from app.shared.base_repository import BaseRepository


class PlayerRepository(BaseRepository[Player]):
    def __init__(self) -> None:
        super().__init__(Player)

    async def get_by_goalserve_id(self, goalserve_id: str) -> Player | None:
        return await Player.find_one(Player.goalserve_id == goalserve_id)

    async def search(
        self,
        q: str | None = None,
        league: str | None = None,
        position: str | None = None,
        team_id: str | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Player], int]:
        conditions = [Player.is_active == True]

        if q:
            conditions.append(RegEx(Player.full_name, q, "i"))
        if league:
            conditions.append(Player.league == league)
        if position:
            conditions.append(Player.position == position)
        if team_id:
            conditions.append(Player.team_goalserve_id == team_id)

        query = Player.find(*conditions).sort(-Player.avg_fantasy_score)
        total = await query.count()
        items = await query.skip(offset).limit(limit).to_list()
        return items, total

    async def upsert_from_goalserve(self, data: dict) -> Player:
        existing = await self.get_by_goalserve_id(data["goalserve_id"])
        if existing:
            return await existing.save_updated(**{k: v for k, v in data.items() if k != "goalserve_id"})
        return await self.create(**data)

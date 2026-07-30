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
        """`data["goalserve_id"]`/`data["team_goalserve_id"]` here are actually
        NBA CDN IDs (see nba_cdn.py) — a different numbering scheme than the
        real Goalserve IDs that box-score syncing (service.py::
        _resolve_goalserve_player) backfills onto goalserve_id/team_goalserve_id
        once a player's been seen in a game. If the ID lookup misses, fall
        back to matching by name — and if THAT hits, skip overwriting
        goalserve_id/team_goalserve_id, so a player already migrated to a
        real Goalserve ID doesn't get silently reverted to the NBA-CDN one
        (which would also orphan their already-synced PlayerGameStats)."""
        existing = await self.get_by_goalserve_id(data["goalserve_id"])
        if existing:
            return await existing.save_updated(**{k: v for k, v in data.items() if k != "goalserve_id"})

        by_name = await Player.find_one(Player.full_name == data["full_name"])
        if by_name:
            safe_fields = {
                k: v for k, v in data.items()
                if k not in ("goalserve_id", "team_goalserve_id")
            }
            return await by_name.save_updated(**safe_fields)

        return await self.create(**data)

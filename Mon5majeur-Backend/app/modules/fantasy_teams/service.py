from beanie import PydanticObjectId

from app.exceptions.errors import BadRequestException, ForbiddenException, NotFoundException
from app.modules.fantasy_teams.constants import MAX_TEAMS_PER_USER
from app.modules.fantasy_teams.model import FantasyTeam
from app.modules.fantasy_teams.repository import FantasyTeamRepository
from app.modules.fantasy_teams.schema import FantasyTeamCreate, FantasyTeamDetailResponse, FantasyTeamUpdate
from app.modules.players.repository import PlayerRepository
from app.modules.users.model import User
from app.shared.pagination import Page, PaginationParams


class FantasyTeamService:
    def __init__(self, team_repo: FantasyTeamRepository, player_repo: PlayerRepository) -> None:
        self.team_repo = team_repo
        self.player_repo = player_repo

    async def _validate_players(self, player_ids: list[PydanticObjectId]) -> None:
        for pid in player_ids:
            player = await self.player_repo.get(pid)
            if not player:
                raise BadRequestException(f"Player {pid} not found")
            if not player.is_active:
                raise BadRequestException(f"Player {player.full_name} is not active")

    async def create_team(self, owner: User, payload: FantasyTeamCreate) -> FantasyTeam:
        count = await self.team_repo.count_by_owner(owner.id)
        if count >= MAX_TEAMS_PER_USER:
            raise BadRequestException(f"Maximum {MAX_TEAMS_PER_USER} teams allowed per user")

        await self._validate_players(payload.player_ids)

        return await self.team_repo.create(
            owner_id=owner.id,
            name=payload.name,
            player_ids=payload.player_ids,
            competition_id=payload.competition_id,
        )

    async def get_my_teams(self, owner: User, params: PaginationParams) -> Page[FantasyTeam]:
        items, total = await self.team_repo.get_by_owner(owner.id, params.offset, params.limit)
        return Page.create(items, total, params)

    async def get_team(self, team_id: PydanticObjectId, requesting_user: User) -> FantasyTeam:
        team = await self.team_repo.get(team_id)
        if not team:
            raise NotFoundException("Team not found")
        if team.owner_id != requesting_user.id and not requesting_user.is_superuser:
            raise ForbiddenException("You do not own this team")
        return team

    async def get_team_with_players(self, team_id: PydanticObjectId, requesting_user: User) -> FantasyTeamDetailResponse:
        team = await self.get_team(team_id, requesting_user)

        from app.modules.players.schema import PlayerResponse
        players = []
        for pid in team.player_ids:
            p = await self.player_repo.get(pid)
            if p:
                players.append(PlayerResponse.model_validate(p))

        detail = FantasyTeamDetailResponse.model_validate(team)
        detail.players = players
        return detail

    async def update_team(self, team_id: PydanticObjectId, owner: User, payload: FantasyTeamUpdate) -> FantasyTeam:
        team = await self.get_team(team_id, owner)
        if team.is_submitted:
            raise BadRequestException("Cannot edit a submitted team")

        updates = payload.model_dump(exclude_unset=True, exclude_none=True)
        if "player_ids" in updates:
            await self._validate_players(updates["player_ids"])

        return await self.team_repo.update(team, **updates)

    async def delete_team(self, team_id: PydanticObjectId, owner: User) -> None:
        team = await self.get_team(team_id, owner)
        if team.is_submitted:
            raise BadRequestException("Cannot delete a submitted team")
        await self.team_repo.delete(team)

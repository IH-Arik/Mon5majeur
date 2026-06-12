from beanie import PydanticObjectId

from app.exceptions.errors import AlreadyExistsException, BadRequestException, NotFoundException
from app.modules.competitions.constants import STATUS_OPEN
from app.modules.competitions.model import Competition, CompetitionEntry
from app.modules.competitions.repository import CompetitionEntryRepository, CompetitionRepository
from app.modules.competitions.schema import (
    CompetitionCreate,
    CompetitionEntryResponse,
    CompetitionUpdate,
    EnterCompetitionRequest,
    LeaderboardEntry,
)
from app.modules.fantasy_teams.repository import FantasyTeamRepository
from app.modules.users.model import User
from app.shared.pagination import Page, PaginationParams


class CompetitionService:
    def __init__(
        self,
        comp_repo: CompetitionRepository,
        entry_repo: CompetitionEntryRepository,
        team_repo: FantasyTeamRepository,
    ) -> None:
        self.comp_repo = comp_repo
        self.entry_repo = entry_repo
        self.team_repo = team_repo

    async def create_competition(self, payload: CompetitionCreate, admin: User) -> Competition:
        return await self.comp_repo.create(**payload.model_dump(), created_by=admin.id)

    async def get_competition(self, competition_id: PydanticObjectId) -> Competition:
        comp = await self.comp_repo.get(competition_id)
        if not comp:
            raise NotFoundException("Competition not found")
        return comp

    async def list_competitions(self, status: str | None, params: PaginationParams) -> Page[Competition]:
        if status:
            items, total = await self.comp_repo.get_by_status(status, params.offset, params.limit)
        else:
            items, total = await self.comp_repo.list(offset=params.offset, limit=params.limit)
        return Page.create(items, total, params)

    async def update_competition(self, competition_id: PydanticObjectId, payload: CompetitionUpdate) -> Competition:
        comp = await self.get_competition(competition_id)
        updates = payload.model_dump(exclude_unset=True, exclude_none=True)
        return await self.comp_repo.update(comp, **updates)

    async def enter_competition(self, competition_id: PydanticObjectId, user: User, payload: EnterCompetitionRequest) -> CompetitionEntry:
        comp = await self.get_competition(competition_id)

        if comp.status != STATUS_OPEN:
            raise BadRequestException("Competition is not open for entries")
        if comp.max_entries and comp.entry_count >= comp.max_entries:
            raise BadRequestException("Competition is full")

        existing = await self.entry_repo.get_entry(competition_id, user.id)
        if existing:
            raise AlreadyExistsException("You have already entered this competition")

        team = await self.team_repo.get(payload.team_id)
        if not team:
            raise BadRequestException("Team not found")
        if team.owner_id != user.id:
            raise BadRequestException("You do not own this team")

        entry = await self.entry_repo.create(
            competition_id=competition_id,
            user_id=user.id,
            team_id=payload.team_id,
        )

        # Lock the team + increment entry count
        await team.save_updated(is_submitted=True, competition_id=competition_id)
        await comp.save_updated(entry_count=comp.entry_count + 1)

        return entry

    async def get_leaderboard(self, competition_id: PydanticObjectId, offset: int = 0, limit: int = 50) -> list[LeaderboardEntry]:
        await self.get_competition(competition_id)
        entries = await self.entry_repo.get_leaderboard(competition_id, offset, limit)
        return [
            LeaderboardEntry(rank=i + 1 + offset, user_id=e.user_id, team_id=e.team_id, score=e.score)
            for i, e in enumerate(entries)
        ]

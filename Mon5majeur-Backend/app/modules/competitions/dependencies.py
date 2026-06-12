from app.modules.competitions.repository import CompetitionEntryRepository, CompetitionRepository
from app.modules.competitions.service import CompetitionService
from app.modules.fantasy_teams.repository import FantasyTeamRepository


def get_competition_service() -> CompetitionService:
    return CompetitionService(CompetitionRepository(), CompetitionEntryRepository(), FantasyTeamRepository())

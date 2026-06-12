from app.modules.fantasy_teams.repository import FantasyTeamRepository
from app.modules.fantasy_teams.service import FantasyTeamService
from app.modules.players.repository import PlayerRepository


def get_fantasy_team_service() -> FantasyTeamService:
    return FantasyTeamService(FantasyTeamRepository(), PlayerRepository())

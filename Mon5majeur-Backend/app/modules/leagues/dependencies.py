from app.modules.leagues.repository import LeagueRepository, MatchRepository, MembershipRepository
from app.modules.leagues.service import LeagueService


def get_league_service() -> LeagueService:
    return LeagueService(
        league_repo=LeagueRepository(),
        membership_repo=MembershipRepository(),
        match_repo=MatchRepository(),
    )

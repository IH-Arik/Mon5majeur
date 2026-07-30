"""
Django-compatible public leagues router.
Mounted at /api (no /v1 prefix) to match the Flutter frontend's hardcoded URLs:

  GET    /api/public-leagues/active_leagues/   → list of joinable public leagues
  POST   /api/public-leagues/join/              → join by integer auto_id
  POST   /api/public-leagues/kick/              → kick a team
  POST   /api/public-leagues/start_league/      → start the league
  POST   /api/public-leagues/                   → create a new public league
  GET    /api/public-leagues/{league_id}/       → waiting room detail by auto_id
  PUT    /api/public-leagues/{league_id}/       → update league
  DELETE /api/public-leagues/{league_id}/       → delete league (204)

Flutter PrivateLeagueModel.fromJson() expects: id (int), leauge_name, leauge_logo,
leauge_description, team_budget, max_team_number, teams, join_code, is_ready, etc.
"""

from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_current_user
from app.modules.leagues.dependencies import get_league_service
from app.modules.leagues.schema import (
    CreatePublicLeagueRequest,
    JoinPublicLeagueByIdRequest,
    KickTeamCompatRequest,
    MatchResultCompatResponse,
    PlayersSelectionGetResponse,
    PlayersSelectionPostResponse,
    PlayersSelectionRequest,
    PlayoffBracketResponse,
    PublicLeagueCompatResponse,
    StartLeagueCompatRequest,
    StandingsResponse,
    UpdateLeagueCompatRequest,
)
from app.modules.leagues import leaderboard_service, selection_service
from app.modules.leagues.service import LeagueService
from app.modules.users.model import User

router = APIRouter(prefix="/public-leagues", tags=["Public Leagues (Flutter compat)"])


# Static paths MUST be declared before the /{league_id} wildcard.

@router.get(
    "/my_leagues/",
    response_model=list[PublicLeagueCompatResponse],
    summary="List current user's public leagues (Flutter: fetchMyLeagues — public variant)",
)
async def my_public_leagues(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[PublicLeagueCompatResponse]:
    return await service.get_my_leagues_compat(current_user, league_type="public")


@router.get(
    "/active_leagues/",
    response_model=list[PublicLeagueCompatResponse],
    summary="List all joinable public leagues (Flutter: getActivePublicLeagues)",
)
async def active_leagues(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[PublicLeagueCompatResponse]:
    return await service.get_active_public_leagues_compat()


@router.post(
    "/join/",
    response_model=dict,
    summary="Join a public league by integer ID (Flutter: joinLeague isPublic=true)",
)
async def join_public_league(
    payload: JoinPublicLeagueByIdRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.join_public_by_auto_id(current_user, payload.league_id)


@router.post(
    "/kick/",
    response_model=dict,
    summary="Kick a team from a public league (Flutter: kickTeamFromLeague isPublic=true)",
)
async def kick_public_team(
    payload: KickTeamCompatRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.kick_member_compat(payload, current_user)


@router.post(
    "/start_league/",
    response_model=dict,
    summary="Start a public league (Flutter: startLeague isPublic=true)",
)
async def start_public_league(
    payload: StartLeagueCompatRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.start_league_compat(payload.league_id, current_user)


@router.post(
    "/",
    response_model=PublicLeagueCompatResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new public league (Flutter: createLeague isPublic=true)",
)
async def create_public_league(
    payload: CreatePublicLeagueRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> PublicLeagueCompatResponse:
    return await service.create_public_league_compat(current_user, payload)


@router.get(
    "/matches/{league_id}/{match_day}/",
    response_model=MatchResultCompatResponse,
    summary="Match result for a public league matchday (Flutter: ResultTab)",
)
async def get_public_match_result(
    league_id: int,
    match_day: int,
    _: User = Depends(get_current_user),
) -> MatchResultCompatResponse:
    data = await selection_service.get_match_result(league_id, match_day)
    return MatchResultCompatResponse(**data)


@router.get(
    "/{league_id}/{match_day}/players-selection/",
    response_model=PlayersSelectionGetResponse,
    summary="Get saved player selection for a public league match day",
)
async def get_public_players_selection(
    league_id: int,
    match_day: int,
    current_user: User = Depends(get_current_user),
) -> PlayersSelectionGetResponse:
    data = await selection_service.get_player_selection(league_id, match_day, current_user)
    return PlayersSelectionGetResponse(**data)


@router.post(
    "/{league_id}/{match_day}/players-selection/",
    response_model=PlayersSelectionPostResponse,
    summary="Submit player selection for a public league match day",
)
async def post_public_players_selection(
    league_id: int,
    match_day: int,
    payload: PlayersSelectionRequest,
    current_user: User = Depends(get_current_user),
) -> PlayersSelectionPostResponse:
    data = await selection_service.save_player_selection(
        league_id, match_day, payload.selected_players, current_user,
        luxury_tax=payload.luxury_tax,
        chef_curry=payload.chef_curry,
        sixth_man_player=payload.sixth_man_player,
    )
    return PlayersSelectionPostResponse(**data)


@router.get(
    "/{league_id}/bonus-status/",
    summary="Combined free-quota + purchased-charge availability per bonus (Flutter: BuildYourTeamTab)",
)
async def get_public_bonus_status(
    league_id: int,
    current_user: User = Depends(get_current_user),
) -> dict:
    return await selection_service.get_bonus_availability(league_id, current_user)


@router.get(
    "/{league_id}/standings/",
    response_model=StandingsResponse,
    summary="Regular season standings for a public league (Flutter: Leaderboard > Regular Season tab)",
)
async def get_public_standings(
    league_id: int,
    _: User = Depends(get_current_user),
) -> StandingsResponse:
    return await leaderboard_service.get_standings(league_id)


@router.get(
    "/{league_id}/playoffs/",
    response_model=PlayoffBracketResponse,
    summary="Playoff bracket for a public league (Flutter: Leaderboard > Play-Off tab)",
)
async def get_public_playoffs(
    league_id: int,
    _: User = Depends(get_current_user),
) -> PlayoffBracketResponse:
    return await leaderboard_service.get_playoff_bracket(league_id)


@router.get(
    "/{league_id}/",
    response_model=PublicLeagueCompatResponse,
    summary="Get public league detail by integer ID (Flutter: getLeagueDetails)",
)
async def get_public_league_detail(
    league_id: int,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> PublicLeagueCompatResponse:
    return await service.get_public_league_by_auto_id(league_id, current_user)


@router.put(
    "/{league_id}/",
    response_model=PublicLeagueCompatResponse,
    summary="Update a public league (Flutter: updateLeague isPublic=true)",
)
async def update_public_league(
    league_id: int,
    payload: UpdateLeagueCompatRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> PublicLeagueCompatResponse:
    return await service.update_league_compat(league_id, current_user, payload)


@router.delete(
    "/{league_id}/",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a public league (Flutter: deleteLeague isPublic=true)",
)
async def delete_public_league(
    league_id: int,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> None:
    await service.delete_league_compat(league_id, current_user)

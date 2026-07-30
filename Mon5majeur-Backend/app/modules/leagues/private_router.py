"""
Django-compatible private leagues router.
Mounted at /api (no /v1 prefix) to match the Flutter frontend's hardcoded URLs:

  POST /api/private-leagues/             → create a new private league
  GET  /api/private-leagues/{league_id}/ → waiting room detail by auto_id
  PATCH /api/private-leagues/{league_id}/→ update league
  DELETE /api/private-leagues/{league_id}/→ delete league (204)
  POST /api/private-leagues/join/        → join by invite code
  POST /api/private-leagues/kick/        → kick a team
  POST /api/private-leagues/start_league/→ start the league

Flutter PrivateLeagueModel.fromJson() expects: id (int), leauge_name, leauge_logo,
leauge_description, team_budget, max_team_number, teams, join_code, is_ready, etc.
"""

from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import get_current_user
from app.modules.leagues.dependencies import get_league_service
from app.modules.leagues.schema import (
    CreatePublicLeagueRequest,
    JoinPrivateLeagueRequest,
    JoinPrivateLeagueResponse,
    KickTeamCompatRequest,
    MatchResultCompatResponse,
    MyMatchTodayCompatResponse,
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

router = APIRouter(prefix="/private-leagues", tags=["Private Leagues (Flutter compat)"])


# Static paths MUST be declared before the /{league_id} wildcard.

@router.get(
    "/my_leagues/",
    response_model=list[PublicLeagueCompatResponse],
    summary="List current user's private leagues (Flutter: fetchMyLeagues)",
)
async def my_private_leagues(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[PublicLeagueCompatResponse]:
    return await service.get_my_leagues_compat(current_user, league_type="private")


@router.get(
    "/matches/my-matches-today/",
    response_model=list[MyMatchTodayCompatResponse],
    summary="Today's matches for the current user (Flutter: fetchTodayMatches)",
)
async def my_matches_today(
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> list[MyMatchTodayCompatResponse]:
    return await service.get_my_matches_today_compat(current_user)


@router.get(
    "/matches/{league_id}/{match_day}/",
    response_model=MatchResultCompatResponse,
    summary="Match result for a private league matchday (Flutter: ResultTab)",
)
async def get_private_match_result(
    league_id: int,
    match_day: int,
    _: User = Depends(get_current_user),
) -> MatchResultCompatResponse:
    data = await selection_service.get_match_result(league_id, match_day)
    return MatchResultCompatResponse(**data)


@router.post(
    "/join/",
    response_model=JoinPrivateLeagueResponse,
    summary="Join a private league by invite code (Flutter: joinLeague isPublic=false)",
)
async def join_private_league(
    payload: JoinPrivateLeagueRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> JoinPrivateLeagueResponse:
    return await service.join_private_by_code(current_user, payload.join_code)


@router.post(
    "/kick/",
    response_model=dict,
    summary="Kick a team from a private league (Flutter: kickTeamFromLeague)",
)
async def kick_team(
    payload: KickTeamCompatRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.kick_member_compat(payload, current_user)


@router.post(
    "/start_league/",
    response_model=dict,
    summary="Start a private league (Flutter: startLeague)",
)
async def start_league(
    payload: StartLeagueCompatRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> dict:
    return await service.start_league_compat(payload.league_id, current_user)


@router.post(
    "/",
    response_model=PublicLeagueCompatResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new private league (Flutter: createLeague isPublic=false)",
)
async def create_private_league(
    payload: CreatePublicLeagueRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> PublicLeagueCompatResponse:
    return await service.create_private_league_compat(current_user, payload)


@router.get(
    "/{league_id}/{match_day}/players-selection/",
    response_model=PlayersSelectionGetResponse,
    summary="Get saved player selection for a private league match day",
)
async def get_private_players_selection(
    league_id: int,
    match_day: int,
    current_user: User = Depends(get_current_user),
) -> PlayersSelectionGetResponse:
    data = await selection_service.get_player_selection(league_id, match_day, current_user)
    return PlayersSelectionGetResponse(**data)


@router.post(
    "/{league_id}/{match_day}/players-selection/",
    response_model=PlayersSelectionPostResponse,
    summary="Submit player selection for a private league match day",
)
async def post_private_players_selection(
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
async def get_private_bonus_status(
    league_id: int,
    current_user: User = Depends(get_current_user),
) -> dict:
    return await selection_service.get_bonus_availability(league_id, current_user)


@router.get(
    "/{league_id}/standings/",
    response_model=StandingsResponse,
    summary="Regular season standings for a private league (Flutter: Leaderboard > Regular Season tab)",
)
async def get_private_standings(
    league_id: int,
    _: User = Depends(get_current_user),
) -> StandingsResponse:
    return await leaderboard_service.get_standings(league_id)


@router.get(
    "/{league_id}/playoffs/",
    response_model=PlayoffBracketResponse,
    summary="Playoff bracket for a private league (Flutter: Leaderboard > Play-Off tab)",
)
async def get_private_playoffs(
    league_id: int,
    _: User = Depends(get_current_user),
) -> PlayoffBracketResponse:
    return await leaderboard_service.get_playoff_bracket(league_id)


@router.get(
    "/{league_id}/",
    response_model=PublicLeagueCompatResponse,
    summary="Get private league detail by integer ID (Flutter: getLeagueDetails)",
)
async def get_private_league_detail(
    league_id: int,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> PublicLeagueCompatResponse:
    return await service.get_private_league_by_auto_id(league_id, current_user)


@router.patch(
    "/{league_id}/",
    response_model=PublicLeagueCompatResponse,
    summary="Update a private league (Flutter: updateLeague isPublic=false)",
)
async def update_private_league(
    league_id: int,
    payload: UpdateLeagueCompatRequest,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> PublicLeagueCompatResponse:
    return await service.update_league_compat(league_id, current_user, payload)


@router.delete(
    "/{league_id}/",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a private league (Flutter: deleteLeague)",
)
async def delete_private_league(
    league_id: int,
    current_user: User = Depends(get_current_user),
    service: LeagueService = Depends(get_league_service),
) -> None:
    await service.delete_league_compat(league_id, current_user)

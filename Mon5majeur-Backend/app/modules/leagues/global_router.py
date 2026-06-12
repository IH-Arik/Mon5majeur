"""
Global League router.
Mounted at /api (no /v1 prefix).

  GET  /api/global-leagues/players-selection/  → fetch user's current selection
  POST /api/global-leagues/players-selection/  → save/update user's selection
"""
from fastapi import APIRouter, Depends

from app.exceptions.errors import NotFoundException
from app.modules.auth.dependencies import get_current_user
from app.modules.leagues.model import League
from app.modules.leagues.schema import GlobalLeagueSelectionResponse, PlayersSelectionRequest
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.users.model import User

router = APIRouter(prefix="/global-leagues", tags=["Global League (Flutter compat)"])

_MAX_BALANCE = 100.0


def _parse_price(raw) -> float:
    """'10.5M' → 10.5   or  10.5 → 10.5"""
    try:
        return float(str(raw).replace("M", "").strip())
    except (ValueError, TypeError):
        return 0.0


async def _get_global_league() -> League:
    league = await League.find_one(League.type == "global")
    if not league:
        raise NotFoundException("Global league not found")
    return league


async def _build_response(
    league: League,
    selected_players: list[dict],
    total_points: int = 0,
) -> GlobalLeagueSelectionResponse:
    used = sum(_parse_price(p.get("price", 0)) for p in selected_players)
    remaining = max(0.0, _MAX_BALANCE - used)

    return GlobalLeagueSelectionResponse(
        match_day=league.current_match_day,
        selected_players=selected_players,
        total_points=total_points,
        max_balance=f"{int(_MAX_BALANCE)}M",
        current_balance=f"{remaining:.0f}M",
    )


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get(
    "/players-selection/",
    response_model=GlobalLeagueSelectionResponse,
    summary="Get user's global league player selection (Flutter: GlobalLeagueController.fetchSelection)",
)
async def get_global_selection(
    current_user: User = Depends(get_current_user),
) -> GlobalLeagueSelectionResponse:
    league = await _get_global_league()

    doc = await FlutterPlayerSelection.find_one({
        "user_id": current_user.id,
        "league_auto_id": league.auto_id,
        "match_day": league.current_match_day,
    })

    if not doc:
        return await _build_response(league, [])

    return await _build_response(league, doc.selected_players)


@router.post(
    "/players-selection/",
    response_model=GlobalLeagueSelectionResponse,
    summary="Save user's global league player selection (Flutter: GlobalLeagueController.saveSelection)",
)
async def post_global_selection(
    payload: PlayersSelectionRequest,
    current_user: User = Depends(get_current_user),
) -> GlobalLeagueSelectionResponse:
    league = await _get_global_league()

    doc = await FlutterPlayerSelection.find_one({
        "user_id": current_user.id,
        "league_auto_id": league.auto_id,
        "match_day": league.current_match_day,
    })

    if doc:
        doc.selected_players = payload.selected_players
        await doc.save()
    else:
        from datetime import datetime, timezone
        doc = FlutterPlayerSelection(
            user_id=current_user.id,
            league_id=league.id,
            league_auto_id=league.auto_id or 0,
            match_day=league.current_match_day,
            selected_players=payload.selected_players,
            submitted_at=datetime.now(timezone.utc),
        )
        await doc.insert()

    return await _build_response(league, doc.selected_players)

"""
WebSocket endpoints for league waiting rooms.

Mounted at the root path (no /api prefix) to match Flutter's hardcoded URLs:
  wss://api.mon5majeur.com/ws/public-leagues/{league_id}/
  wss://api.mon5majeur.com/ws/private-leagues/{league_id}/

league_id is the auto_id integer (Flutter's int? id field).
"""

import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.websocket import broadcast, connect, disconnect

logger = logging.getLogger(__name__)

router = APIRouter(tags=["WebSockets"])


# Close codes (4000-4999 are free for applications).
WS_UNAUTHORIZED = 4401
WS_FORBIDDEN = 4403


async def ws_user(token: str | None):
    """The user behind an access token, or None (invalid, expired, inactive)."""
    from beanie import PydanticObjectId
    from jose import JWTError

    from app.core.security import decode_token
    from app.modules.users.repository import UserRepository

    if not token:
        return None
    try:
        payload = decode_token(token)
    except JWTError:
        return None
    if payload.get("type") != "access" or not payload.get("sub"):
        return None
    try:
        user = await UserRepository().get(PydanticObjectId(payload["sub"]))
    except Exception:  # noqa: BLE001
        return None
    return user if user is not None and user.is_active else None


async def may_listen(user, league_id: int, league_type: str) -> bool:
    """A private league's events are for its members only; a public league is
    open to everyone, so any signed-in player may watch its waiting room.

    The rule follows the league's real type, not the socket path: the app
    opens a public league joined by code in the private waiting room."""
    from app.modules.leagues.model import League, LeagueMembership

    league = await League.find_one(League.auto_id == league_id)
    if league is None:
        return False
    if league.type == "public" or user.is_superuser:
        return True
    return await LeagueMembership.find_one(
        LeagueMembership.league_id == league.id,
        LeagueMembership.user_id == user.id,
    ) is not None


async def _serve(league_id: int, websocket: WebSocket, league_type: str, token: str | None) -> None:
    # Who connects is checked before joining the room (Arik QA item 14): the
    # player's access token comes as ?token=, since a browser or mobile socket
    # cannot always set an Authorization header.
    user = await ws_user(token)
    if user is None:
        await websocket.close(code=WS_UNAUTHORIZED)
        return
    if not await may_listen(user, league_id, league_type):
        await websocket.close(code=WS_FORBIDDEN)
        return
    await connect(league_id, websocket)
    try:
        while True:
            # Keep the connection alive; server only pushes, client doesn't send
            await websocket.receive_text()
    except WebSocketDisconnect:
        disconnect(league_id, websocket)


@router.websocket("/ws/public-leagues/{league_id}/")
async def public_league_ws(league_id: int, websocket: WebSocket, token: str | None = None) -> None:
    await _serve(league_id, websocket, "public", token)


@router.websocket("/ws/private-leagues/{league_id}/")
async def private_league_ws(league_id: int, websocket: WebSocket, token: str | None = None) -> None:
    await _serve(league_id, websocket, "private", token)


# Convenience helpers called from service methods ─────────────────────────────

async def emit_team_joined(league_auto_id: int, team_id: int | None, team_name: str, team_logo: str, user_id: str) -> None:
    await broadcast(league_auto_id, "team_joined", {
        "league_id": league_auto_id,
        "user": user_id,
        "team_id": team_id,
        "team_name": team_name,
        "team_logo": team_logo,
    })


async def emit_team_left(league_auto_id: int, team_id: int | None, team_name: str) -> None:
    await broadcast(league_auto_id, "team_left", {
        "league_id": league_auto_id,
        "team_id": team_id,
        "team_name": team_name,
    })


async def emit_team_kicked(league_auto_id: int, team_id: int | None, team_name: str) -> None:
    await broadcast(league_auto_id, "team_kicked", {
        "league_id": league_auto_id,
        "team_id": team_id,
        "team_name": team_name,
    })


async def emit_league_started(league_auto_id: int) -> None:
    await broadcast(league_auto_id, "league_started", {
        "league_id": league_auto_id,
        "message": "The league has started!",
    })

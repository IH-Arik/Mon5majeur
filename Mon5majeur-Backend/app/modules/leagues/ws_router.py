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


@router.websocket("/ws/public-leagues/{league_id}/")
async def public_league_ws(league_id: int, websocket: WebSocket) -> None:
    await connect(league_id, websocket)
    try:
        while True:
            # Keep the connection alive; server only pushes, client doesn't send
            await websocket.receive_text()
    except WebSocketDisconnect:
        disconnect(league_id, websocket)


@router.websocket("/ws/private-leagues/{league_id}/")
async def private_league_ws(league_id: int, websocket: WebSocket) -> None:
    await connect(league_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        disconnect(league_id, websocket)


# Convenience helpers called from service methods ─────────────────────────────

async def emit_team_joined(league_auto_id: int, team_id: int | None, team_name: str, team_logo: str, user_id: str) -> None:
    await broadcast(league_auto_id, "team_joined", {
        "user": user_id,
        "team_id": team_id,
        "team_name": team_name,
        "team_logo": team_logo,
    })


async def emit_team_left(league_auto_id: int, team_id: int | None, team_name: str) -> None:
    await broadcast(league_auto_id, "team_left", {
        "team_id": team_id,
        "team_name": team_name,
    })


async def emit_team_kicked(league_auto_id: int, team_id: int | None, team_name: str) -> None:
    await broadcast(league_auto_id, "team_kicked", {
        "team_id": team_id,
        "team_name": team_name,
    })


async def emit_league_started(league_auto_id: int) -> None:
    await broadcast(league_auto_id, "league_started", {
        "message": "The league has started!",
    })

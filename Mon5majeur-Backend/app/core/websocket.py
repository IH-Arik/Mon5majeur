"""
WebSocket connection manager for league waiting rooms.

League rooms are keyed by auto_id (int) — the sequential integer ID Flutter uses.
Each connection is tagged with its league_type ("public" or "private") so the
public and private WebSocket paths share the same in-memory manager.
"""

import json
import logging
from collections import defaultdict

from fastapi import WebSocket

logger = logging.getLogger(__name__)

# {league_auto_id: set[WebSocket]}
_connections: dict[int, set[WebSocket]] = defaultdict(set)


async def connect(league_id: int, ws: WebSocket) -> None:
    await ws.accept()
    _connections[league_id].add(ws)
    logger.info("WS connected league=%d total=%d", league_id, len(_connections[league_id]))


def disconnect(league_id: int, ws: WebSocket) -> None:
    _connections[league_id].discard(ws)
    if not _connections[league_id]:
        del _connections[league_id]
    logger.info("WS disconnected league=%d", league_id)


async def broadcast(league_id: int, event: str, payload: dict) -> None:
    """Send an event to every client in this league room."""
    message = json.dumps({"type": "event", "event": event, "payload": payload})
    dead: list[WebSocket] = []
    for ws in list(_connections.get(league_id, [])):
        try:
            await ws.send_text(message)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _connections[league_id].discard(ws)

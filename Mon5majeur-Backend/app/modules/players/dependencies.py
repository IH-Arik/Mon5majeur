from app.modules.players.repository import PlayerRepository
from app.modules.players.service import PlayerService


def get_player_service() -> PlayerService:
    return PlayerService(PlayerRepository())

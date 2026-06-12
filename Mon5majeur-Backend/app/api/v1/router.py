from fastapi import APIRouter

from app.modules.auth.router import router as auth_router
from app.modules.competitions.router import router as competitions_router
from app.modules.fantasy_teams.router import router as fantasy_teams_router
from app.modules.files.router import router as files_router
from app.modules.home.router import router as home_router
from app.modules.leagues.router import router as leagues_router
from app.modules.lineups.router import router as lineups_router
from app.modules.live_scores.router import router as live_router
from app.modules.tokens.router import router as tokens_router
from app.modules.notifications.router import router as notifications_router
from app.modules.permissions.router import router as permissions_router
from app.modules.players.router import router as players_router
from app.modules.roles.router import router as roles_router
from app.modules.users.router import router as users_router

api_v1_router = APIRouter()

api_v1_router.include_router(home_router)
api_v1_router.include_router(auth_router)
api_v1_router.include_router(users_router)
api_v1_router.include_router(leagues_router)
api_v1_router.include_router(players_router)
api_v1_router.include_router(lineups_router)
api_v1_router.include_router(tokens_router)
api_v1_router.include_router(live_router)
api_v1_router.include_router(fantasy_teams_router)
api_v1_router.include_router(competitions_router)
api_v1_router.include_router(notifications_router)
api_v1_router.include_router(files_router)
api_v1_router.include_router(roles_router)
api_v1_router.include_router(permissions_router)

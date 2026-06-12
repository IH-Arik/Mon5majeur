from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import api_v1_router
from app.core.config import settings
from app.core.events import lifespan
from app.exceptions.handlers import register_exception_handlers
from app.middleware.cors import add_cors_middleware
from app.middleware.logging import RequestLoggingMiddleware
from app.modules.auth.compat_router import router as auth_compat_router
from app.modules.leagues.global_router import router as global_leagues_compat_router
from app.modules.leagues.private_router import router as private_leagues_compat_router
from app.modules.leagues.public_router import router as public_leagues_compat_router
from app.modules.leagues.rules_router import router as league_rules_router
from app.modules.leagues.ws_router import router as ws_router
from app.modules.players.compat_router import router as players_compat_router
from app.modules.users.profile_router import router as user_profiles_compat_router


def create_application() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
        docs_url=f"{settings.API_V1_PREFIX}/docs",
        redoc_url=f"{settings.API_V1_PREFIX}/redoc",
        lifespan=lifespan,
    )

    add_cors_middleware(app)
    app.add_middleware(RequestLoggingMiddleware)
    register_exception_handlers(app)

    app.include_router(api_v1_router, prefix=settings.API_V1_PREFIX)
    # Flutter-compat routers: /api/public-leagues/... /api/private-leagues/... /api/UserProfiles/
    app.include_router(auth_compat_router, prefix="/api")
    app.include_router(public_leagues_compat_router, prefix="/api")
    app.include_router(private_leagues_compat_router, prefix="/api")
    app.include_router(global_leagues_compat_router, prefix="/api")
    app.include_router(user_profiles_compat_router, prefix="/api")
    app.include_router(players_compat_router, prefix="/api")
    app.include_router(league_rules_router, prefix="/api")
    # WebSocket: wss://api.mon5majeur.com/ws/public-leagues/{id}/ and /ws/private-leagues/{id}/
    app.include_router(ws_router)

    # Serve uploaded files (creates folder if missing)
    upload_path = Path(settings.UPLOAD_DIR)
    upload_path.mkdir(parents=True, exist_ok=True)
    app.mount("/static", StaticFiles(directory=str(upload_path)), name="static")

    @app.get("/health", tags=["Health"])
    async def health() -> dict:
        return {"status": "ok", "version": settings.APP_VERSION}

    return app


app = create_application()

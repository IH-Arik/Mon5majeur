import traceback

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from jose import JWTError
from pymongo.errors import DuplicateKeyError

from app.core.logging import get_logger
from app.exceptions.errors import AppException

logger = get_logger(__name__)


def _error_response(status_code: int, detail: str, headers: dict | None = None) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"detail": detail, "status_code": status_code},
        headers=headers,
    )


def register_exception_handlers(app: FastAPI) -> None:

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
        logger.warning("AppException [%s]: %s | path=%s", exc.status_code, exc.detail, request.url.path)
        return _error_response(exc.status_code, exc.detail, exc.headers)

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
        errors = [{"field": ".".join(str(l) for l in e["loc"]), "msg": e["msg"]} for e in exc.errors()]
        logger.warning("Validation error | path=%s | errors=%s", request.url.path, errors)
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"detail": "Validation error", "errors": errors, "status_code": 422},
        )

    @app.exception_handler(JWTError)
    async def jwt_exception_handler(request: Request, exc: JWTError) -> JSONResponse:
        return _error_response(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token", {"WWW-Authenticate": "Bearer"})

    @app.exception_handler(DuplicateKeyError)
    async def duplicate_key_error_handler(request: Request, exc: DuplicateKeyError) -> JSONResponse:
        logger.error("DB DuplicateKeyError | path=%s | %s", request.url.path, str(exc))
        return _error_response(status.HTTP_409_CONFLICT, "Data conflict — record may already exist")

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.critical("Unhandled exception | path=%s\n%s", request.url.path, traceback.format_exc())
        return _error_response(status.HTTP_500_INTERNAL_SERVER_ERROR, "Internal server error")

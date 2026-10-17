from typing import Any


class AppException(Exception):
    status_code: int = 500
    detail: str = "Internal server error"
    headers: dict[str, str] | None = None

    def __init__(
        self,
        detail: str | None = None,
        headers: dict[str, str] | None = None,
        extra: dict[str, Any] | None = None,
    ) -> None:
        self.detail = detail or self.__class__.detail
        self.headers = headers
        self.extra = extra or {}
        super().__init__(self.detail)


class NotFoundException(AppException):
    status_code = 404
    detail = "Resource not found"


class AlreadyExistsException(AppException):
    status_code = 409
    detail = "Resource already exists"


class UnauthorizedException(AppException):
    status_code = 401
    detail = "Not authenticated"
    headers = {"WWW-Authenticate": "Bearer"}


class ForbiddenException(AppException):
    status_code = 403
    detail = "Permission denied"


class LineupLockedException(ForbiddenException):
    """403 for any lineup or bonus change while the night is locked (QA #13
    addendum). The body carries a machine-readable code and the moment the
    composition reopens, so the app never has to guess."""

    detail = "Lineup is locked until the 9:00 AM publication"

    def __init__(self, reopens_at: str | None = None, detail: str | None = None) -> None:
        super().__init__(
            detail,
            extra={"code": "lineup_locked", "reopens_at": reopens_at},
        )


class ValidationException(AppException):
    status_code = 422
    detail = "Validation error"


class BadRequestException(AppException):
    status_code = 400
    detail = "Bad request"


class RateLimitException(AppException):
    status_code = 429
    detail = "Too many requests"

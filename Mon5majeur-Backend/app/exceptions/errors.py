from typing import Any


class AppException(Exception):
    status_code: int = 500
    detail: str = "Internal server error"
    headers: dict[str, str] | None = None

    def __init__(self, detail: str | None = None, headers: dict[str, str] | None = None) -> None:
        self.detail = detail or self.__class__.detail
        self.headers = headers
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


class ValidationException(AppException):
    status_code = 422
    detail = "Validation error"


class BadRequestException(AppException):
    status_code = 400
    detail = "Bad request"


class RateLimitException(AppException):
    status_code = 429
    detail = "Too many requests"

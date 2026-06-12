from app.shared.base_schema import BaseResponseSchema, BaseSchema


class PermissionCreate(BaseSchema):
    name: str
    codename: str
    description: str | None = None
    resource: str
    action: str


class PermissionResponse(BaseResponseSchema):
    name: str
    codename: str
    description: str | None
    resource: str
    action: str

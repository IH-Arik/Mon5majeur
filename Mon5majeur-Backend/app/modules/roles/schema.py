from app.shared.base_schema import BaseResponseSchema, BaseSchema


class RoleCreate(BaseSchema):
    name: str
    description: str | None = None


class RoleUpdate(BaseSchema):
    name: str | None = None
    description: str | None = None


class RoleResponse(BaseResponseSchema):
    name: str
    description: str | None
    is_system: bool

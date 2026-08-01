from datetime import datetime

from beanie import PydanticObjectId
from pydantic import BaseModel, ConfigDict


class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class BaseResponseSchema(BaseSchema):
    id: PydanticObjectId
    created_at: datetime
    updated_at: datetime

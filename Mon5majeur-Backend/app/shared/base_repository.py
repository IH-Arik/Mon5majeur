from typing import Any, Generic, Sequence, Type, TypeVar

from beanie import PydanticObjectId

from app.database.base import BaseDocument

DocT = TypeVar("DocT", bound=BaseDocument)


class BaseRepository(Generic[DocT]):
    def __init__(self, model: Type[DocT]) -> None:
        self.model = model

    async def get(self, id: PydanticObjectId) -> DocT | None:
        return await self.model.get(id)

    async def get_or_raise(self, id: PydanticObjectId) -> DocT:
        obj = await self.get(id)
        if obj is None:
            raise ValueError(f"{self.model.__name__} with id={id} not found")
        return obj

    async def list(
        self,
        *,
        offset: int = 0,
        limit: int = 20,
        filters: dict[str, Any] | None = None,
    ) -> tuple[Sequence[DocT], int]:
        query = self.model.find(filters or {})
        total = await query.count()
        items = await query.skip(offset).limit(limit).to_list()
        return items, total

    async def create(self, **kwargs: Any) -> DocT:
        obj = self.model(**kwargs)
        await obj.insert()
        return obj

    async def update(self, obj: DocT, **kwargs: Any) -> DocT:
        return await obj.save_updated(**kwargs)

    async def delete(self, obj: DocT) -> None:
        await obj.delete()

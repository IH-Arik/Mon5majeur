import math
from typing import Generic, Sequence, TypeVar

from fastapi import Query
from pydantic import BaseModel

from app.core.config import settings

T = TypeVar("T")


class PaginationParams:
    def __init__(
        self,
        page: int = Query(1, ge=1, description="Page number"),
        size: int = Query(settings.DEFAULT_PAGE_SIZE, ge=1, le=settings.MAX_PAGE_SIZE, description="Items per page"),
    ) -> None:
        self.page = page
        self.size = size

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.size

    @property
    def limit(self) -> int:
        return self.size


class PageMeta(BaseModel):
    page: int
    size: int
    total: int
    pages: int


class Page(BaseModel, Generic[T]):
    data: Sequence[T]
    meta: PageMeta

    @classmethod
    def create(cls, data: Sequence[T], total: int, params: PaginationParams) -> "Page[T]":
        return cls(
            data=data,
            meta=PageMeta(
                page=params.page,
                size=params.size,
                total=total,
                pages=math.ceil(total / params.size) if params.size else 0,
            ),
        )

from datetime import datetime, timezone
from typing import Any, ClassVar

from beanie import Document
from pydantic import Field
from pymongo import IndexModel


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class BaseDocument(Document):
    """
    Project-wide base for all Beanie documents.
    Provides created_at / updated_at and a helper for partial updates.
    """

    created_at: datetime = Field(default_factory=_utcnow)
    updated_at: datetime = Field(default_factory=_utcnow)

    class Settings:
        use_state_management = True

    async def save_updated(self, **kwargs: Any) -> "BaseDocument":
        """Update fields + bump updated_at, then save."""
        kwargs["updated_at"] = _utcnow()
        for field, value in kwargs.items():
            setattr(self, field, value)
        await self.save()
        return self

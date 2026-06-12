from __future__ import annotations

from datetime import date, datetime, timezone

from beanie import PydanticObjectId

from app.modules.bonuses.model import UserBonusQuota


class BonusService:

    async def get_quota(
        self, user_id: PydanticObjectId, league_id: PydanticObjectId
    ) -> UserBonusQuota:
        quota = await UserBonusQuota.find_one(
            UserBonusQuota.user_id == user_id,
            UserBonusQuota.league_id == league_id,
        )
        if not quota:
            quota = UserBonusQuota(user_id=user_id, league_id=league_id)
            await quota.insert()
        return quota

    async def can_use(
        self,
        user_id: PydanticObjectId,
        league_id: PydanticObjectId,
        bonus: str,
    ) -> bool:
        quota = await self.get_quota(user_id, league_id)
        return not getattr(quota, f"{bonus}_used")

    async def consume(
        self,
        user_id: PydanticObjectId,
        league_id: PydanticObjectId,
        bonus: str,
    ) -> None:
        """Mark bonus as used. Raises ValueError if already used."""
        quota = await self.get_quota(user_id, league_id)
        if getattr(quota, f"{bonus}_used"):
            raise ValueError(f"Bonus '{bonus}' already used in this league")
        today = datetime.now(timezone.utc).date()
        setattr(quota, f"{bonus}_used", True)
        setattr(quota, f"{bonus}_used_date", today)
        await quota.save()

    async def get_status(
        self, user_id: PydanticObjectId, league_id: PydanticObjectId
    ) -> dict:
        quota = await self.get_quota(user_id, league_id)
        return {
            "luxury_tax": {
                "used": quota.luxury_tax_used,
                "used_date": quota.luxury_tax_used_date,
            },
            "chef_curry": {
                "used": quota.chef_curry_used,
                "used_date": quota.chef_curry_used_date,
            },
            "sixth_man": {
                "used": quota.sixth_man_used,
                "used_date": quota.sixth_man_used_date,
            },
        }

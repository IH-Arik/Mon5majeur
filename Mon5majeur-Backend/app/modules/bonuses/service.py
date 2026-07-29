from __future__ import annotations

from datetime import datetime, timezone

from beanie import PydanticObjectId

from app.modules.bonuses.constants import free_quota_for
from app.modules.bonuses.model import UserBonusInventory, UserBonusQuota


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

    async def _get_inventory(self, user_id: PydanticObjectId) -> UserBonusInventory:
        inv = await UserBonusInventory.find_one(UserBonusInventory.user_id == user_id)
        if not inv:
            inv = UserBonusInventory(user_id=user_id)
            await inv.insert()
        return inv

    async def can_use(
        self,
        user_id: PydanticObjectId,
        league_id: PydanticObjectId,
        bonus: str,
    ) -> bool:
        """Free league quota (sized by league.max_size) first, then
        shop-purchased charges (spec §4.4: "beyond the quota → buy per unit
        with tokens")."""
        from app.modules.leagues.model import League

        league = await League.get(league_id)
        max_size = league.max_size if league else 4

        quota = await self.get_quota(user_id, league_id)
        used = getattr(quota, f"{bonus}_used_count")
        if used < free_quota_for(max_size, bonus):
            return True

        inv = await self._get_inventory(user_id)
        return getattr(inv, f"{bonus}_charges") > 0

    async def consume(
        self,
        user_id: PydanticObjectId,
        league_id: PydanticObjectId,
        bonus: str,
    ) -> None:
        """Consume one use: free quota first, then a purchased charge.
        Raises ValueError if neither is available."""
        from app.modules.leagues.model import League

        league = await League.get(league_id)
        max_size = league.max_size if league else 4

        quota = await self.get_quota(user_id, league_id)
        used = getattr(quota, f"{bonus}_used_count")
        today = datetime.now(timezone.utc).date()

        if used < free_quota_for(max_size, bonus):
            setattr(quota, f"{bonus}_used_count", used + 1)
            setattr(quota, f"{bonus}_last_used_date", today)
            await quota.save()
            return

        inv = await self._get_inventory(user_id)
        charges = getattr(inv, f"{bonus}_charges")
        if charges <= 0:
            raise ValueError(f"Bonus '{bonus}' has no free quota or purchased charges left")
        setattr(inv, f"{bonus}_charges", charges - 1)
        await inv.save()

    async def refund(
        self,
        user_id: PydanticObjectId,
        league_id: PydanticObjectId,
        bonus: str,
    ) -> None:
        """Reverse one consumed use (user deactivated the bonus before lock).
        Best-effort: gives back to free quota first (assumes that's what a
        consume() right before would have drawn from), else to purchased
        charges. Never raises — deactivating is always allowed."""
        quota = await self.get_quota(user_id, league_id)
        used = getattr(quota, f"{bonus}_used_count")
        if used > 0:
            setattr(quota, f"{bonus}_used_count", used - 1)
            await quota.save()
        else:
            inv = await self._get_inventory(user_id)
            field = f"{bonus}_charges"
            setattr(inv, field, getattr(inv, field) + 1)
            await inv.save()

    async def get_status(
        self, user_id: PydanticObjectId, league_id: PydanticObjectId
    ) -> dict:
        from app.modules.leagues.model import League

        league = await League.get(league_id)
        max_size = league.max_size if league else 4
        quota = await self.get_quota(user_id, league_id)
        inv = await self._get_inventory(user_id)

        def _bonus_status(bonus: str) -> dict:
            free_quota = free_quota_for(max_size, bonus)
            used = getattr(quota, f"{bonus}_used_count")
            return {
                "free_quota": free_quota,
                "free_used": used,
                "free_remaining": max(0, free_quota - used),
                "purchased_charges": getattr(inv, f"{bonus}_charges"),
                "used_date": getattr(quota, f"{bonus}_last_used_date"),
            }

        return {
            "luxury_tax": _bonus_status("luxury_tax"),
            "chef_curry": _bonus_status("chef_curry"),
            "sixth_man": _bonus_status("sixth_man"),
        }

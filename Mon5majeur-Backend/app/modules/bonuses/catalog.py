"""
The admin-editable half of the bonus catalog: 5 fixed slugs, DB-backed price
and active/inactive state. Replaces the old hardcoded BONUS_COSTS dict as the
source of truth — that dict's values now live here only as seed defaults for
first boot.
"""
from __future__ import annotations

from app.modules.bonuses.model import BonusOffer, BonusSlug

# (display_name, default token_cost) — the defaults previously hardcoded in
# tokens.model.BONUS_COSTS, used only to seed the DB the first time.
BONUS_DEFAULTS: dict[BonusSlug, tuple[str, int]] = {
    "chef_curry": ("Chef Curry", 130),
    "sixth_man": ("6th Man", 170),
    "luxury_tax": ("Luxury Tax", 150),
    "live_scoring": ("Live Scoring", 200),
    "stop_pub": ("Stop Pub", 450),
}


async def ensure_seeded() -> None:
    for slug, (display_name, token_cost) in BONUS_DEFAULTS.items():
        existing = await BonusOffer.find_one(BonusOffer.slug == slug)
        if not existing:
            await BonusOffer(slug=slug, display_name=display_name, token_cost=token_cost).insert()


async def list_offers() -> list[BonusOffer]:
    await ensure_seeded()
    order = {slug: i for i, slug in enumerate(BONUS_DEFAULTS)}
    offers = await BonusOffer.find_all().to_list()
    return sorted(offers, key=lambda o: order.get(o.slug, 99))


async def get_offer(slug: str) -> BonusOffer | None:
    if slug not in BONUS_DEFAULTS:
        return None
    await ensure_seeded()
    return await BonusOffer.find_one(BonusOffer.slug == slug)


async def get_active_cost(slug: str) -> int | None:
    """Token cost if the bonus exists and is active, else None."""
    offer = await get_offer(slug)
    if offer is None or not offer.is_active:
        return None
    return offer.token_cost

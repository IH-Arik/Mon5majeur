"""
The admin-editable half of the token-pack catalog: 4 fixed slugs, DB-backed
token amount / display price / active state. Replaces the old hardcoded
_MOCK_PACK_TOKENS dict as the source of truth for /mock-purchase.
"""
from __future__ import annotations

from app.modules.tokens.model import TokenPack, TokenPackSlug

# (display_name, token_amount, price_usd) — the real prices shown in the
# Flutter shop (buy_token.dart / app_strings.dart), used only to seed the DB
# the first time.
TOKEN_PACK_DEFAULTS: dict[TokenPackSlug, tuple[str, int, float]] = {
    "rookie": ("Rookie Pack", 200, 1.99),
    "all_star": ("All-Star Pack", 550, 4.99),
    "mvp": ("MVP Pack", 1200, 9.99),
    "hall_of_fame": ("Hall of Fame Pack", 2500, 19.99),
}


async def ensure_seeded() -> None:
    for slug, (display_name, token_amount, price_usd) in TOKEN_PACK_DEFAULTS.items():
        existing = await TokenPack.find_one(TokenPack.slug == slug)
        if not existing:
            await TokenPack(
                slug=slug,
                display_name=display_name,
                token_amount=token_amount,
                price_usd=price_usd,
            ).insert()


async def list_packs() -> list[TokenPack]:
    await ensure_seeded()
    order = {slug: i for i, slug in enumerate(TOKEN_PACK_DEFAULTS)}
    packs = await TokenPack.find_all().to_list()
    return sorted(packs, key=lambda p: order.get(p.slug, 99))


async def get_pack(slug: str) -> TokenPack | None:
    if slug not in TOKEN_PACK_DEFAULTS:
        return None
    await ensure_seeded()
    return await TokenPack.find_one(TokenPack.slug == slug)


async def get_active_token_amount(slug: str) -> int | None:
    """Token amount if the pack exists and is active, else None."""
    pack = await get_pack(slug)
    if pack is None or not pack.is_active:
        return None
    return pack.token_amount

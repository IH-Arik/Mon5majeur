"""
Seeding and fetch helpers for the content-pages/FAQ catalog. The DB is the
source of truth once seeded — seeds.py only supplies the first-boot defaults.
"""
from __future__ import annotations

from app.modules.content.model import ContentPageDoc, FaqEntryDoc
from app.modules.content.seeds import FAQ_SEEDS, PAGE_SEEDS


async def ensure_pages_seeded() -> None:
    for slug, defaults in PAGE_SEEDS.items():
        existing = await ContentPageDoc.find_one(ContentPageDoc.slug == slug)
        if not existing:
            await ContentPageDoc(slug=slug, title=defaults["title"], body=defaults["body"]).insert()


async def ensure_faqs_seeded() -> None:
    if await FaqEntryDoc.find_all().count() > 0:
        return
    for i, entry in enumerate(FAQ_SEEDS):
        await FaqEntryDoc(question=entry["question"], answer=entry["answer"], order=i).insert()


async def get_page(slug: str) -> ContentPageDoc | None:
    if slug not in PAGE_SEEDS:
        return None
    await ensure_pages_seeded()
    return await ContentPageDoc.find_one(ContentPageDoc.slug == slug)


async def list_pages() -> list[ContentPageDoc]:
    await ensure_pages_seeded()
    order = {slug: i for i, slug in enumerate(PAGE_SEEDS)}
    pages = await ContentPageDoc.find_all().to_list()
    return sorted(pages, key=lambda p: order.get(p.slug, 99))


async def list_active_faqs() -> list[FaqEntryDoc]:
    await ensure_faqs_seeded()
    return await FaqEntryDoc.find(FaqEntryDoc.is_active == True).sort(+FaqEntryDoc.order).to_list()  # noqa: E712


async def list_all_faqs() -> list[FaqEntryDoc]:
    await ensure_faqs_seeded()
    return await FaqEntryDoc.find_all().sort(+FaqEntryDoc.order).to_list()

"""
Static content & GDPR-required pages (spec §5.3).
Mounted at /api (no /v1 prefix) to match Flutter's expected paths.

Content is DB-backed (see content.model / content.catalog) and editable from
the admin dashboard (content.admin_router) — these endpoints just serve
whatever is currently stored, seeded from seeds.py on first boot.
"""
from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

from app.modules.content import catalog

router = APIRouter(tags=["Static Content (GDPR)"])


class ContentPage(BaseModel):
    title: str
    body: str


class FaqItem(BaseModel):
    question: str
    answer: str


async def _page_or_placeholder(slug: str) -> ContentPage:
    page = await catalog.get_page(slug)
    if page is None:
        # Only reachable if seeding somehow failed to run — never actually
        # expected, but an empty page is safer for the app than a 500.
        return ContentPage(title="", body="")
    return ContentPage(title=page.title, body=page.body)


@router.get("/aboutus/", response_model=ContentPage, summary="About Us (Flutter compat)")
async def about_us() -> ContentPage:
    return await _page_or_placeholder("about_us")


@router.get("/legal-notices/", response_model=ContentPage, summary="Legal notices (Flutter compat)")
async def legal_notices() -> ContentPage:
    return await _page_or_placeholder("legal_notices")


@router.get("/privacy-policies/", response_model=ContentPage, summary="Privacy policy (Flutter compat)")
async def privacy_policy() -> ContentPage:
    return await _page_or_placeholder("privacy_policy")


@router.get("/terms-of-use/", response_model=ContentPage, summary="Terms of use (Flutter compat)")
async def terms_of_use() -> ContentPage:
    return await _page_or_placeholder("terms_of_use")


@router.get("/faqs/", response_model=list[FaqItem], summary="FAQ list (Flutter compat)")
async def faqs() -> list[FaqItem]:
    entries = await catalog.list_active_faqs()
    return [FaqItem(question=e.question, answer=e.answer) for e in entries]

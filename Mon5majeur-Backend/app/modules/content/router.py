"""
Static content & GDPR-required pages (spec §5.3).
Mounted at /api (no /v1 prefix) to match Flutter's expected paths.

Content is DB-backed (see content.model / content.catalog) and editable from
the admin dashboard (content.admin_router) — these endpoints just serve
whatever is currently stored, seeded from seeds.py on first boot.
"""
from __future__ import annotations

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.modules.content import catalog

router = APIRouter(tags=["Static Content (GDPR)"])


class ContentPage(BaseModel):
    title: str
    body: str


class FaqItem(BaseModel):
    question: str
    answer: str


async def _page_or_placeholder(slug: str, lang: str) -> ContentPage:
    page = await catalog.get_page(slug)
    if page is None:
        # Only reachable if seeding somehow failed to run — never actually
        # expected, but an empty page is safer for the app than a 500.
        return ContentPage(title="", body="")
    # Fall back to English whenever the French copy hasn't been filled in
    # yet, rather than showing a half-translated or blank page.
    if lang == "fr" and page.title_fr and page.body_fr:
        return ContentPage(title=page.title_fr, body=page.body_fr)
    return ContentPage(title=page.title, body=page.body)


_LangQuery = Query("en", pattern="^(en|fr)$", description="Language of the returned copy")


@router.get("/aboutus/", response_model=ContentPage, summary="About Us (Flutter compat)")
async def about_us(lang: str = _LangQuery) -> ContentPage:
    return await _page_or_placeholder("about_us", lang)


@router.get("/legal-notices/", response_model=ContentPage, summary="Legal notices (Flutter compat)")
async def legal_notices(lang: str = _LangQuery) -> ContentPage:
    return await _page_or_placeholder("legal_notices", lang)


@router.get("/privacy-policies/", response_model=ContentPage, summary="Privacy policy (Flutter compat)")
async def privacy_policy(lang: str = _LangQuery) -> ContentPage:
    return await _page_or_placeholder("privacy_policy", lang)


@router.get("/terms-of-use/", response_model=ContentPage, summary="Terms of use (Flutter compat)")
async def terms_of_use(lang: str = _LangQuery) -> ContentPage:
    return await _page_or_placeholder("terms_of_use", lang)


@router.get("/faqs/", response_model=list[FaqItem], summary="FAQ list (Flutter compat)")
async def faqs() -> list[FaqItem]:
    entries = await catalog.list_active_faqs()
    return [FaqItem(question=e.question, answer=e.answer) for e in entries]

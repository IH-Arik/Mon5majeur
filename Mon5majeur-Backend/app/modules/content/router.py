"""
Static content & GDPR-required pages (spec §5.3).
Mounted at /api (no /v1 prefix) to match Flutter's expected paths.

⚠️ Placeholder content only. These are NOT real legal/privacy text — a
lawyer or the founder must supply the actual copy before launch. This
module exists so the endpoints are reachable and the app has something
non-empty to render meanwhile.
"""
from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(tags=["Static Content (GDPR)"])


class ContentPage(BaseModel):
    title: str
    body: str


class FaqItem(BaseModel):
    question: str
    answer: str


_ABOUT_US = ContentPage(
    title="About Us",
    body="TODO: replace with real About Us copy before launch.",
)

_LEGAL_NOTICES = ContentPage(
    title="Legal Notices",
    body=(
        "TODO: replace with real legal notices (publisher identity, hosting "
        "provider, contact details) before launch — required by French law "
        "(mentions légales)."
    ),
)

_PRIVACY_POLICY = ContentPage(
    title="Privacy Policy",
    body=(
        "TODO: replace with a real GDPR-compliant privacy policy before "
        "launch, covering: what personal data is collected (email, phone/OTP, "
        "pseudo, game history, token purchases), why, how long it's kept, "
        "who it's shared with, and how a user can request access/export/"
        "deletion of their data."
    ),
)

_FAQS: list[FaqItem] = [
    FaqItem(
        question="TODO: real FAQ content needed",
        answer="Replace this placeholder list with real FAQ entries before launch.",
    ),
]


@router.get("/aboutus/", response_model=ContentPage, summary="About Us (Flutter compat)")
async def about_us() -> ContentPage:
    return _ABOUT_US


@router.get("/legal-notices/", response_model=ContentPage, summary="Legal notices (Flutter compat)")
async def legal_notices() -> ContentPage:
    return _LEGAL_NOTICES


@router.get("/privacy-policies/", response_model=ContentPage, summary="Privacy policy (Flutter compat)")
async def privacy_policy() -> ContentPage:
    return _PRIVACY_POLICY


@router.get("/faqs/", response_model=list[FaqItem], summary="FAQ list (Flutter compat)")
async def faqs() -> list[FaqItem]:
    return _FAQS

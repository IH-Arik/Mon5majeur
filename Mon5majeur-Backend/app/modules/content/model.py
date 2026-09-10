from typing import Literal

from pymongo import ASCENDING, IndexModel

from app.database.base import BaseDocument

ContentSlug = Literal["about_us", "legal_notices", "privacy_policy", "terms_of_use"]


class ContentPageDoc(BaseDocument):
    """One of the 4 fixed static pages the Flutter app renders (About Us,
    Legal Notices, Privacy Policy, Terms of Use) — admin-editable text, no
    create/delete since the app only knows how to fetch these 4 slugs.

    title/body are the English copy (unchanged field names, so existing
    seeded documents keep working with no migration). title_fr/body_fr are
    the French copy, added for QA4-dashboard #4 - empty until an admin
    fills them in, in which case the app falls back to the English copy
    (see content.router._page_or_placeholder) rather than showing a blank
    page for content not yet translated.
    """
    slug: ContentSlug
    title: str
    body: str
    title_fr: str = ""
    body_fr: str = ""

    class Settings:
        name = "content_pages"
        indexes = [IndexModel([("slug", ASCENDING)], unique=True)]


class FaqEntryDoc(BaseDocument):
    """Free-form — unlike the content pages, admins can add/remove FAQ
    entries, since the app just renders whatever list comes back."""
    question: str
    answer: str
    order: int = 0
    is_active: bool = True

    class Settings:
        name = "faq_entries"
        indexes = [IndexModel([("order", ASCENDING)])]

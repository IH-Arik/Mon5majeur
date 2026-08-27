"""
Admin (dashboard) management of static content pages and FAQ entries.
Mounted at /api to match the dashboard's hardcoded base URL.
"""
from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from app.exceptions.errors import NotFoundException
from app.modules.auth.dependencies import get_current_superuser
from app.modules.content import catalog
from app.modules.content.model import FaqEntryDoc

router = APIRouter(
    prefix="/admin/content",
    tags=["Admin: Content & FAQ"],
    dependencies=[Depends(get_current_superuser)],
)


# ── Static pages (About Us / Legal Notices / Privacy Policy / Terms of Use) ──

class ContentPageResponse(BaseModel):
    slug: str
    title: str
    body: str


class ContentPageUpdateRequest(BaseModel):
    title: str | None = None
    body: str | None = None


@router.get(
    "/pages/",
    response_model=list[ContentPageResponse],
    summary="List the 4 static content pages",
)
async def list_pages() -> list[ContentPageResponse]:
    pages = await catalog.list_pages()
    return [ContentPageResponse(slug=p.slug, title=p.title, body=p.body) for p in pages]


@router.patch(
    "/pages/{slug}/",
    response_model=ContentPageResponse,
    summary="Update a static page's title and/or body",
)
async def update_page(slug: str, payload: ContentPageUpdateRequest) -> ContentPageResponse:
    page = await catalog.get_page(slug)
    if page is None:
        raise NotFoundException(f"Unknown content page: {slug}")

    updates = payload.model_dump(exclude_none=True)
    if updates:
        await page.save_updated(**updates)
    return ContentPageResponse(slug=page.slug, title=page.title, body=page.body)


# ── FAQ entries (free-form — can be created/removed, unlike the 4 pages) ────

class FaqEntryResponse(BaseModel):
    id: str
    question: str
    answer: str
    order: int
    is_active: bool


class FaqEntryCreateRequest(BaseModel):
    question: str
    answer: str


class FaqEntryUpdateRequest(BaseModel):
    question: str | None = None
    answer: str | None = None
    order: int | None = None
    is_active: bool | None = None


def _to_faq_response(entry: FaqEntryDoc) -> FaqEntryResponse:
    return FaqEntryResponse(
        id=str(entry.id),
        question=entry.question,
        answer=entry.answer,
        order=entry.order,
        is_active=entry.is_active,
    )


@router.get("/faqs/", response_model=list[FaqEntryResponse], summary="List all FAQ entries")
async def list_faqs() -> list[FaqEntryResponse]:
    entries = await catalog.list_all_faqs()
    return [_to_faq_response(e) for e in entries]


@router.post(
    "/faqs/",
    response_model=FaqEntryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new FAQ entry",
)
async def create_faq(payload: FaqEntryCreateRequest) -> FaqEntryResponse:
    last = await FaqEntryDoc.find_all().sort(-FaqEntryDoc.order).limit(1).to_list()
    next_order = (last[0].order + 1) if last else 0
    entry = await FaqEntryDoc(
        question=payload.question, answer=payload.answer, order=next_order
    ).insert()
    return _to_faq_response(entry)


@router.patch("/faqs/{faq_id}/", response_model=FaqEntryResponse, summary="Update a FAQ entry")
async def update_faq(faq_id: PydanticObjectId, payload: FaqEntryUpdateRequest) -> FaqEntryResponse:
    entry = await FaqEntryDoc.get(faq_id)
    if entry is None:
        raise NotFoundException("FAQ entry not found")

    updates = payload.model_dump(exclude_none=True)
    if updates:
        await entry.save_updated(**updates)
    return _to_faq_response(entry)


@router.delete(
    "/faqs/{faq_id}/", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a FAQ entry"
)
async def delete_faq(faq_id: PydanticObjectId) -> None:
    entry = await FaqEntryDoc.get(faq_id)
    if entry is None:
        raise NotFoundException("FAQ entry not found")
    await entry.delete()

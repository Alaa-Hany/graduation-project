from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from deps import get_db
from models import ContentCategory, ContentItem, Quiz

router = APIRouter(tags=["content"])

PUBLIC_PAGE_SLUGS = {
    "about": "about",
    "faq": "help-faq",
    "terms": "legal-terms",
    "privacy": "legal-privacy",
    "coppa": "legal-coppa",
}
PUBLIC_CHILD_CONTENT_TYPES = {"lesson", "story", "video", "activity"}


def _published_content_query(db: Session):
    return (
        db.query(ContentItem)
        .options(
            joinedload(ContentItem.category),
            joinedload(ContentItem.quizzes).joinedload(Quiz.category),
        )
        .filter(
            ContentItem.deleted_at.is_(None),
            ContentItem.status == "published",
            ContentItem.published_at.is_not(None),
        )
    )


def _published_quiz_query(db: Session):
    return (
        db.query(Quiz)
        .options(
            joinedload(Quiz.category),
            joinedload(Quiz.content).joinedload(ContentItem.category),
        )
        .filter(
            Quiz.deleted_at.is_(None),
            Quiz.status == "published",
            Quiz.published_at.is_not(None),
        )
    )


def _serialize_public_category(category: ContentCategory) -> dict[str, Any]:
    active_contents = [
        item
        for item in (category.contents or [])
        if item.deleted_at is None and item.status == "published" and item.published_at is not None
    ]
    active_quizzes = [
        item
        for item in (category.quizzes or [])
        if item.deleted_at is None and item.status == "published" and item.published_at is not None
    ]
    return {
        "id": category.id,
        "slug": category.slug,
        "title_en": category.title_en,
        "title_ar": category.title_ar,
        "description_en": category.description_en,
        "description_ar": category.description_ar,
        "content_count": len(active_contents),
        "quiz_count": len(active_quizzes),
    }


def _serialize_public_quiz(quiz: Quiz) -> dict[str, Any]:
    return {
        "id": quiz.id,
        "content_id": quiz.content_id,
        "category_id": quiz.category_id,
        "title_en": quiz.title_en,
        "title_ar": quiz.title_ar,
        "description_en": quiz.description_en,
        "description_ar": quiz.description_ar,
        "question_count": len(quiz.questions_json or []),
        "questions_json": quiz.questions_json or [],
        "published_at": quiz.published_at.isoformat() if quiz.published_at else None,
    }


def _serialize_public_content_item(
    content: ContentItem,
    *,
    include_quizzes: bool = False,
) -> dict[str, Any]:
    payload = {
        "id": content.id,
        "slug": content.slug,
        "category_id": content.category_id,
        "content_type": content.content_type,
        "title_en": content.title_en,
        "title_ar": content.title_ar,
        "description_en": content.description_en,
        "description_ar": content.description_ar,
        "body_en": content.body_en,
        "body_ar": content.body_ar,
        "thumbnail_url": content.thumbnail_url,
        "age_group": content.age_group,
        "metadata_json": content.metadata_json or {},
        "category": (
            _serialize_public_category(content.category) if content.category is not None else None
        ),
        "published_at": content.published_at.isoformat() if content.published_at else None,
    }
    if include_quizzes:
        payload["quizzes"] = [
            _serialize_public_quiz(quiz)
            for quiz in (content.quizzes or [])
            if quiz.deleted_at is None and quiz.status == "published" and quiz.published_at is not None
        ]
    return payload


def _get_published_page_or_404(*, db: Session, slug: str) -> ContentItem:
    page = (
        _published_content_query(db)
        .filter(ContentItem.content_type == "page", ContentItem.slug == slug.lower())
        .first()
    )
    if page is None:
        raise HTTPException(status_code=404, detail="Content page not found")
    return page


def _body_from_page(page: ContentItem) -> str:
    return (page.body_en or page.body_ar or "").strip()


def _faq_items_from_page(page: ContentItem) -> list[dict[str, Any]]:
    raw_items = (page.metadata_json or {}).get("faq_items") or []
    items: list[dict[str, Any]] = []
    for index, item in enumerate(raw_items):
        if not isinstance(item, dict):
            continue
        question_en = str(item.get("question_en") or item.get("question") or "").strip()
        question_ar = str(item.get("question_ar") or "").strip()
        answer_en = str(item.get("answer_en") or item.get("answer") or "").strip()
        answer_ar = str(item.get("answer_ar") or "").strip()
        question = str(item.get("question") or question_en or question_ar or item.get("title") or "").strip()
        answer = str(item.get("answer") or answer_en or answer_ar or item.get("body") or "").strip()
        if not question or not answer:
            continue
        items.append(
            {
                "id": str(item.get("id") or index + 1),
                "question": question,
                "answer": answer,
                "question_en": question_en or None,
                "question_ar": question_ar or None,
                "answer_en": answer_en or None,
                "answer_ar": answer_ar or None,
            }
        )
    return items


@router.get("/content/pages/{slug}")
def get_public_page(slug: str, db: Session = Depends(get_db)):
    page = _get_published_page_or_404(db=db, slug=slug)
    return {"item": _serialize_public_content_item(page)}


@router.get("/content/help-faq")
def help_faq(db: Session = Depends(get_db)):
    page = _get_published_page_or_404(db=db, slug=PUBLIC_PAGE_SLUGS["faq"])
    return {
        "title": page.title_en,
        "body": _body_from_page(page),
        "items": _faq_items_from_page(page),
        "item": _serialize_public_content_item(page),
    }


@router.get("/content/about")
def about(db: Session = Depends(get_db)):
    page = _get_published_page_or_404(db=db, slug=PUBLIC_PAGE_SLUGS["about"])
    return {
        "title": page.title_en,
        "body": _body_from_page(page),
        "item": _serialize_public_content_item(page),
    }


@router.get("/legal/terms")
def terms(db: Session = Depends(get_db)):
    page = _get_published_page_or_404(db=db, slug=PUBLIC_PAGE_SLUGS["terms"])
    body = _body_from_page(page)
    return {"body": body, "content": body, "item": _serialize_public_content_item(page)}


@router.get("/legal/privacy")
def privacy(db: Session = Depends(get_db)):
    page = _get_published_page_or_404(db=db, slug=PUBLIC_PAGE_SLUGS["privacy"])
    body = _body_from_page(page)
    return {"body": body, "content": body, "item": _serialize_public_content_item(page)}


@router.get("/legal/coppa")
def coppa(db: Session = Depends(get_db)):
    page = _get_published_page_or_404(db=db, slug=PUBLIC_PAGE_SLUGS["coppa"])
    body = _body_from_page(page)
    return {"body": body, "content": body, "item": _serialize_public_content_item(page)}


@router.get("/content/child/categories")
def list_child_content_categories(db: Session = Depends(get_db)):
    categories = (
        db.query(ContentCategory)
        .options(joinedload(ContentCategory.contents), joinedload(ContentCategory.quizzes))
        .filter(ContentCategory.deleted_at.is_(None))
        .all()
    )
    items = []
    for category in categories:
        if any(
            content.deleted_at is None
            and content.status == "published"
            and content.published_at is not None
            and content.content_type in PUBLIC_CHILD_CONTENT_TYPES
            for content in (category.contents or [])
        ):
            items.append(_serialize_public_category(category))
    items.sort(key=lambda item: item["title_en"].lower())
    return {"items": items}


@router.get("/content/child/items")
def list_child_content_items(
    category_slug: str | None = None,
    content_type: str | None = None,
    age: int | None = None,
    search: str | None = None,
    db: Session = Depends(get_db),
):
    query = _published_content_query(db).filter(ContentItem.content_type.in_(PUBLIC_CHILD_CONTENT_TYPES))

    if category_slug:
        query = query.join(ContentItem.category).filter(ContentCategory.slug == category_slug.lower())
    if content_type:
        normalized_type = content_type.strip().lower()
        if normalized_type not in PUBLIC_CHILD_CONTENT_TYPES:
            raise HTTPException(status_code=400, detail="Invalid child content type")
        query = query.filter(ContentItem.content_type == normalized_type)
    if search and search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.filter(
            ContentItem.slug.ilike(term)
            | ContentItem.title_en.ilike(term)
            | ContentItem.title_ar.ilike(term)
            | ContentItem.description_en.ilike(term)
            | ContentItem.description_ar.ilike(term)
        )

    items = query.order_by(ContentItem.published_at.desc(), ContentItem.id.desc()).all()
    if age is not None:
        filtered: list[ContentItem] = []
        for item in items:
            age_group = (item.age_group or "").strip()
            if not age_group:
                filtered.append(item)
                continue
            if age_group.endswith("+"):
                minimum = int(age_group[:-1])
                if age >= minimum:
                    filtered.append(item)
                continue
            if "-" in age_group:
                start_raw, end_raw = age_group.split("-", 1)
                start, end = int(start_raw), int(end_raw)
                if start <= age <= end:
                    filtered.append(item)
        items = filtered

    return {"items": [_serialize_public_content_item(item, include_quizzes=True) for item in items]}


@router.get("/content/child/items/{slug}")
def get_child_content_item(slug: str, db: Session = Depends(get_db)):
    item = (
        _published_content_query(db)
        .filter(
            ContentItem.slug == slug.lower(),
            ContentItem.content_type.in_(PUBLIC_CHILD_CONTENT_TYPES),
        )
        .first()
    )
    if item is None:
        raise HTTPException(status_code=404, detail="Child content item not found")
    return {"item": _serialize_public_content_item(item, include_quizzes=True)}


@router.get("/content/child/quizzes")
def list_child_quizzes(
    category_slug: str | None = None,
    content_slug: str | None = None,
    db: Session = Depends(get_db),
):
    query = _published_quiz_query(db)
    if category_slug:
        query = query.join(Quiz.category).filter(ContentCategory.slug == category_slug.lower())
    if content_slug:
        query = query.join(Quiz.content).filter(ContentItem.slug == content_slug.lower())
    items = query.order_by(Quiz.published_at.desc(), Quiz.id.desc()).all()
    return {"items": [_serialize_public_quiz(item) for item in items]}

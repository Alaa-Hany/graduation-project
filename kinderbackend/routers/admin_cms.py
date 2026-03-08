from __future__ import annotations

import re
from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from admin_deps import require_permission
from admin_utils import (
    build_pagination_payload,
    serialize_content_category,
    serialize_content_item,
    serialize_quiz,
    write_audit_log,
)
from deps import get_db
from models import ContentCategory, ContentItem, Quiz

router = APIRouter(tags=["Admin CMS"])

CONTENT_STATUSES = {"draft", "review", "published"}


class CategoryCreateRequest(BaseModel):
    slug: Optional[str] = None
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None


class CategoryUpdateRequest(BaseModel):
    slug: Optional[str] = None
    title_en: Optional[str] = None
    title_ar: Optional[str] = None
    description_en: Optional[str] = None
    description_ar: Optional[str] = None


class ContentCreateRequest(BaseModel):
    category_id: Optional[int] = None
    content_type: str = "lesson"
    status: str = "draft"
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    body_en: Optional[str] = None
    body_ar: Optional[str] = None
    thumbnail_url: Optional[str] = None
    age_group: Optional[str] = None
    metadata_json: Optional[dict[str, Any]] = None


class ContentUpdateRequest(BaseModel):
    category_id: Optional[int] = None
    content_type: Optional[str] = None
    status: Optional[str] = None
    title_en: Optional[str] = None
    title_ar: Optional[str] = None
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    body_en: Optional[str] = None
    body_ar: Optional[str] = None
    thumbnail_url: Optional[str] = None
    age_group: Optional[str] = None
    metadata_json: Optional[dict[str, Any]] = None


class QuizCreateRequest(BaseModel):
    content_id: Optional[int] = None
    category_id: Optional[int] = None
    status: str = "draft"
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    questions_json: list[dict[str, Any]] = Field(default_factory=list)


class QuizUpdateRequest(BaseModel):
    content_id: Optional[int] = None
    category_id: Optional[int] = None
    status: Optional[str] = None
    title_en: Optional[str] = None
    title_ar: Optional[str] = None
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    questions_json: Optional[list[dict[str, Any]]] = None


def _slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.strip().lower())
    return slug.strip("-")


def _normalize_status(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in CONTENT_STATUSES:
        raise HTTPException(status_code=400, detail="Status must be draft, review, or published")
    return normalized


def _categories_query(db: Session):
    return db.query(ContentCategory).options(
        joinedload(ContentCategory.contents),
        joinedload(ContentCategory.quizzes),
    )


def _contents_query(db: Session):
    return db.query(ContentItem).options(
        joinedload(ContentItem.category).joinedload(ContentCategory.contents),
        joinedload(ContentItem.category).joinedload(ContentCategory.quizzes),
        joinedload(ContentItem.creator),
        joinedload(ContentItem.updater),
        joinedload(ContentItem.quizzes).joinedload(Quiz.category),
    )


def _quizzes_query(db: Session):
    return db.query(Quiz).options(
        joinedload(Quiz.category).joinedload(ContentCategory.contents),
        joinedload(Quiz.content).joinedload(ContentItem.category),
        joinedload(Quiz.creator),
        joinedload(Quiz.updater),
    )


def _get_category_or_404(category_id: int, db: Session) -> ContentCategory:
    category = (
        _categories_query(db)
        .filter(ContentCategory.id == category_id, ContentCategory.deleted_at.is_(None))
        .first()
    )
    if category is None:
        raise HTTPException(status_code=404, detail="Category not found")
    return category


def _get_content_or_404(content_id: int, db: Session) -> ContentItem:
    content = (
        _contents_query(db)
        .filter(ContentItem.id == content_id, ContentItem.deleted_at.is_(None))
        .first()
    )
    if content is None:
        raise HTTPException(status_code=404, detail="Content not found")
    return content


def _get_quiz_or_404(quiz_id: int, db: Session) -> Quiz:
    quiz = (
        _quizzes_query(db)
        .filter(Quiz.id == quiz_id, Quiz.deleted_at.is_(None))
        .first()
    )
    if quiz is None:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return quiz


def _ensure_category_exists(category_id: Optional[int], db: Session) -> None:
    if category_id is None:
        return
    _get_category_or_404(category_id, db)


def _ensure_content_exists(content_id: Optional[int], db: Session) -> None:
    if content_id is None:
        return
    _get_content_or_404(content_id, db)


@router.get("/admin/categories")
def list_categories(
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.view")),
):
    items = (
        _categories_query(db)
        .filter(ContentCategory.deleted_at.is_(None))
        .order_by(func.lower(ContentCategory.title_en))
        .all()
    )
    return {"items": [serialize_content_category(item) for item in items]}


@router.post("/admin/categories")
def create_category(
    payload: CategoryCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.create")),
):
    slug = _slugify(payload.slug or payload.title_en)
    if not slug:
        raise HTTPException(status_code=400, detail="Category slug is required")
    duplicate = db.query(ContentCategory).filter(func.lower(ContentCategory.slug) == slug).first()
    if duplicate is not None:
        raise HTTPException(status_code=400, detail="Category slug already exists")

    category = ContentCategory(
        slug=slug,
        title_en=payload.title_en.strip(),
        title_ar=payload.title_ar.strip(),
        description_en=payload.description_en.strip() if payload.description_en else None,
        description_ar=payload.description_ar.strip() if payload.description_ar else None,
        created_by=admin.id,
        updated_by=admin.id,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(category)
    db.flush()
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="category.create",
        entity_type="category",
        entity_id=category.id,
        after_json=serialize_content_category(category),
    )
    db.commit()
    db.refresh(category)
    return {"success": True, "item": serialize_content_category(category)}


@router.patch("/admin/categories/{category_id}")
def update_category(
    category_id: int,
    payload: CategoryUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.edit")),
):
    category = _get_category_or_404(category_id, db)
    before = serialize_content_category(category)

    if payload.slug is not None:
        slug = _slugify(payload.slug)
        if not slug:
            raise HTTPException(status_code=400, detail="Category slug is required")
        duplicate = (
            db.query(ContentCategory)
            .filter(func.lower(ContentCategory.slug) == slug, ContentCategory.id != category.id)
            .first()
        )
        if duplicate is not None:
            raise HTTPException(status_code=400, detail="Category slug already exists")
        category.slug = slug

    if payload.title_en is not None:
        category.title_en = payload.title_en.strip()
    if payload.title_ar is not None:
        category.title_ar = payload.title_ar.strip()
    if payload.description_en is not None:
        category.description_en = payload.description_en.strip()
    if payload.description_ar is not None:
        category.description_ar = payload.description_ar.strip()

    category.updated_by = admin.id
    category.updated_at = datetime.utcnow()
    db.add(category)
    db.flush()
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="category.edit",
        entity_type="category",
        entity_id=category.id,
        before_json=before,
        after_json=serialize_content_category(category),
    )
    db.commit()
    db.refresh(category)
    return {"success": True, "item": serialize_content_category(category)}


@router.delete("/admin/categories/{category_id}")
def delete_category(
    category_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.delete")),
):
    category = _get_category_or_404(category_id, db)
    active_contents = [item for item in (category.contents or []) if item.deleted_at is None]
    active_quizzes = [item for item in (category.quizzes or []) if item.deleted_at is None]
    if active_contents or active_quizzes:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete a category that still has content or quizzes",
        )

    before = serialize_content_category(category)
    category.deleted_at = datetime.utcnow()
    category.updated_by = admin.id
    category.updated_at = datetime.utcnow()
    db.add(category)
    db.flush()
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="category.delete",
        entity_type="category",
        entity_id=category.id,
        before_json=before,
        after_json={"id": category.id, "deleted_at": category.deleted_at.isoformat()},
    )
    db.commit()
    return {"success": True}


@router.get("/admin/contents")
def list_contents(
    search: str = Query("", description="Search titles"),
    status_filter: str = Query("", alias="status"),
    category_id: Optional[int] = Query(None),
    content_type: str = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.view")),
):
    query = _contents_query(db).filter(ContentItem.deleted_at.is_(None))

    if search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.filter(
            func.lower(ContentItem.title_en).like(term)
            | func.lower(ContentItem.title_ar).like(term)
            | func.lower(func.coalesce(ContentItem.description_en, "")).like(term)
            | func.lower(func.coalesce(ContentItem.description_ar, "")).like(term)
        )
    if status_filter.strip():
        query = query.filter(ContentItem.status == _normalize_status(status_filter))
    if category_id is not None:
        query = query.filter(ContentItem.category_id == category_id)
    if content_type.strip():
        query = query.filter(ContentItem.content_type == content_type.strip().lower())

    total = query.count()
    items = (
        query.order_by(ContentItem.updated_at.desc(), ContentItem.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [serialize_content_item(item) for item in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
        "filters": {
            "search": search,
            "status": status_filter.strip().lower(),
            "category_id": category_id,
            "content_type": content_type.strip().lower(),
        },
    }


@router.get("/admin/contents/{content_id}")
def get_content(
    content_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.view")),
):
    content = _get_content_or_404(content_id, db)
    return {"item": serialize_content_item(content, include_quizzes=True)}


@router.post("/admin/contents")
def create_content(
    payload: ContentCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.create")),
):
    _ensure_category_exists(payload.category_id, db)
    status_value = _normalize_status(payload.status)
    published_at = datetime.utcnow() if status_value == "published" else None

    content = ContentItem(
        category_id=payload.category_id,
        content_type=payload.content_type.strip().lower(),
        status=status_value,
        title_en=payload.title_en.strip(),
        title_ar=payload.title_ar.strip(),
        description_en=payload.description_en.strip() if payload.description_en else None,
        description_ar=payload.description_ar.strip() if payload.description_ar else None,
        body_en=payload.body_en,
        body_ar=payload.body_ar,
        thumbnail_url=payload.thumbnail_url,
        age_group=payload.age_group,
        metadata_json=payload.metadata_json or {},
        created_by=admin.id,
        updated_by=admin.id,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        published_at=published_at,
    )
    db.add(content)
    db.flush()
    content = _get_content_or_404(content.id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="content.create",
        entity_type="content",
        entity_id=content.id,
        after_json=serialize_content_item(content, include_quizzes=True),
    )
    db.commit()
    content = _get_content_or_404(content.id, db)
    return {"success": True, "item": serialize_content_item(content, include_quizzes=True)}


@router.patch("/admin/contents/{content_id}")
def update_content(
    content_id: int,
    payload: ContentUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.edit")),
):
    content = _get_content_or_404(content_id, db)
    before = serialize_content_item(content, include_quizzes=True)

    if payload.category_id is not None:
        _ensure_category_exists(payload.category_id, db)
        content.category_id = payload.category_id
    if payload.content_type is not None:
        content.content_type = payload.content_type.strip().lower()
    if payload.status is not None:
        content.status = _normalize_status(payload.status)
        content.published_at = datetime.utcnow() if content.status == "published" else None
    if payload.title_en is not None:
        content.title_en = payload.title_en.strip()
    if payload.title_ar is not None:
        content.title_ar = payload.title_ar.strip()
    if payload.description_en is not None:
        content.description_en = payload.description_en.strip()
    if payload.description_ar is not None:
        content.description_ar = payload.description_ar.strip()
    if payload.body_en is not None:
        content.body_en = payload.body_en
    if payload.body_ar is not None:
        content.body_ar = payload.body_ar
    if payload.thumbnail_url is not None:
        content.thumbnail_url = payload.thumbnail_url
    if payload.age_group is not None:
        content.age_group = payload.age_group
    if payload.metadata_json is not None:
        content.metadata_json = payload.metadata_json

    content.updated_by = admin.id
    content.updated_at = datetime.utcnow()
    db.add(content)
    db.flush()
    content = _get_content_or_404(content_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="content.edit",
        entity_type="content",
        entity_id=content.id,
        before_json=before,
        after_json=serialize_content_item(content, include_quizzes=True),
    )
    db.commit()
    content = _get_content_or_404(content_id, db)
    return {"success": True, "item": serialize_content_item(content, include_quizzes=True)}


@router.post("/admin/contents/{content_id}/publish")
def publish_content(
    content_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.publish")),
):
    content = _get_content_or_404(content_id, db)
    before = serialize_content_item(content, include_quizzes=True)
    content.status = "published"
    content.published_at = datetime.utcnow()
    content.updated_by = admin.id
    content.updated_at = datetime.utcnow()
    db.add(content)
    db.flush()
    content = _get_content_or_404(content_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="content.publish",
        entity_type="content",
        entity_id=content.id,
        before_json=before,
        after_json=serialize_content_item(content, include_quizzes=True),
    )
    db.commit()
    return {"success": True, "item": serialize_content_item(content, include_quizzes=True)}


@router.post("/admin/contents/{content_id}/unpublish")
def unpublish_content(
    content_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.publish")),
):
    content = _get_content_or_404(content_id, db)
    before = serialize_content_item(content, include_quizzes=True)
    content.status = "draft"
    content.published_at = None
    content.updated_by = admin.id
    content.updated_at = datetime.utcnow()
    db.add(content)
    db.flush()
    content = _get_content_or_404(content_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="content.unpublish",
        entity_type="content",
        entity_id=content.id,
        before_json=before,
        after_json=serialize_content_item(content, include_quizzes=True),
    )
    db.commit()
    return {"success": True, "item": serialize_content_item(content, include_quizzes=True)}


@router.delete("/admin/contents/{content_id}")
def delete_content(
    content_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.delete")),
):
    content = _get_content_or_404(content_id, db)
    before = serialize_content_item(content, include_quizzes=True)
    content.deleted_at = datetime.utcnow()
    content.updated_by = admin.id
    content.updated_at = datetime.utcnow()
    db.add(content)
    db.flush()
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="content.delete",
        entity_type="content",
        entity_id=content.id,
        before_json=before,
        after_json={"id": content.id, "deleted_at": content.deleted_at.isoformat()},
    )
    db.commit()
    return {"success": True}


@router.get("/admin/quizzes")
def list_quizzes(
    status_filter: str = Query("", alias="status"),
    category_id: Optional[int] = Query(None),
    content_id: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.view")),
):
    query = _quizzes_query(db).filter(Quiz.deleted_at.is_(None))
    if status_filter.strip():
        query = query.filter(Quiz.status == _normalize_status(status_filter))
    if category_id is not None:
        query = query.filter(Quiz.category_id == category_id)
    if content_id is not None:
        query = query.filter(Quiz.content_id == content_id)

    total = query.count()
    items = (
        query.order_by(Quiz.updated_at.desc(), Quiz.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [serialize_quiz(item) for item in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
    }


@router.post("/admin/quizzes")
def create_quiz(
    payload: QuizCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.create")),
):
    _ensure_category_exists(payload.category_id, db)
    _ensure_content_exists(payload.content_id, db)
    status_value = _normalize_status(payload.status)
    quiz = Quiz(
        content_id=payload.content_id,
        category_id=payload.category_id,
        status=status_value,
        title_en=payload.title_en.strip(),
        title_ar=payload.title_ar.strip(),
        description_en=payload.description_en.strip() if payload.description_en else None,
        description_ar=payload.description_ar.strip() if payload.description_ar else None,
        questions_json=payload.questions_json,
        created_by=admin.id,
        updated_by=admin.id,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        published_at=datetime.utcnow() if status_value == "published" else None,
    )
    db.add(quiz)
    db.flush()
    quiz = _get_quiz_or_404(quiz.id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="quiz.create",
        entity_type="quiz",
        entity_id=quiz.id,
        after_json=serialize_quiz(quiz),
    )
    db.commit()
    quiz = _get_quiz_or_404(quiz.id, db)
    return {"success": True, "item": serialize_quiz(quiz)}


@router.patch("/admin/quizzes/{quiz_id}")
def update_quiz(
    quiz_id: int,
    payload: QuizUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.edit")),
):
    quiz = _get_quiz_or_404(quiz_id, db)
    before = serialize_quiz(quiz)

    if payload.content_id is not None:
        _ensure_content_exists(payload.content_id, db)
        quiz.content_id = payload.content_id
    if payload.category_id is not None:
        _ensure_category_exists(payload.category_id, db)
        quiz.category_id = payload.category_id
    if payload.status is not None:
        quiz.status = _normalize_status(payload.status)
        quiz.published_at = datetime.utcnow() if quiz.status == "published" else None
    if payload.title_en is not None:
        quiz.title_en = payload.title_en.strip()
    if payload.title_ar is not None:
        quiz.title_ar = payload.title_ar.strip()
    if payload.description_en is not None:
        quiz.description_en = payload.description_en.strip()
    if payload.description_ar is not None:
        quiz.description_ar = payload.description_ar.strip()
    if payload.questions_json is not None:
        quiz.questions_json = payload.questions_json

    quiz.updated_by = admin.id
    quiz.updated_at = datetime.utcnow()
    db.add(quiz)
    db.flush()
    quiz = _get_quiz_or_404(quiz_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="quiz.edit",
        entity_type="quiz",
        entity_id=quiz.id,
        before_json=before,
        after_json=serialize_quiz(quiz),
    )
    db.commit()
    quiz = _get_quiz_or_404(quiz.id, db)
    return {"success": True, "item": serialize_quiz(quiz)}


@router.delete("/admin/quizzes/{quiz_id}")
def delete_quiz(
    quiz_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.delete")),
):
    quiz = _get_quiz_or_404(quiz_id, db)
    before = serialize_quiz(quiz)
    quiz.deleted_at = datetime.utcnow()
    quiz.updated_by = admin.id
    quiz.updated_at = datetime.utcnow()
    db.add(quiz)
    db.flush()
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="quiz.delete",
        entity_type="quiz",
        entity_id=quiz.id,
        before_json=before,
        after_json={"id": quiz.id, "deleted_at": quiz.deleted_at.isoformat()},
    )
    db.commit()
    return {"success": True}

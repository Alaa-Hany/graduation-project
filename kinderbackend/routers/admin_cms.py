from __future__ import annotations

import re
from typing import Any, Optional
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from admin_deps import ensure_permission, get_current_admin, require_permission
from admin_utils import (
    CONTENT_AXIS_METADATA,
    build_pagination_payload,
    normalize_content_axis_key,
    serialize_content_axis_summary,
    serialize_content_category,
    serialize_content_item,
    serialize_quiz,
    write_audit_log,
)
from core.settings import settings
from core.admin_security import require_sensitive_action_confirmation
from core.observability import emit_event
from core.time_utils import db_utc_now
from deps import get_db
from models import ContentCategory, ContentItem, Quiz
from services.media_service import MediaServiceError, media_service

router = APIRouter(tags=["Admin CMS"])

CONTENT_STATUSES = {"draft", "ready", "review", "published", "archived"}
PUBLISHED_STATUS = "published"
READY_STATUS = "ready"
ARCHIVED_STATUS = "archived"
CONTENT_TYPES = {"lesson", "story", "video", "activity", "page"}
AGE_GROUP_PATTERN = re.compile(r"^\s*(\d{1,2}\s*-\s*\d{1,2}|\d{1,2}\+)\s*$")


class CategoryCreateRequest(BaseModel):
    axis_key: str
    slug: Optional[str] = None
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None


class CategoryUpdateRequest(BaseModel):
    axis_key: Optional[str] = None
    slug: Optional[str] = None
    title_en: Optional[str] = None
    title_ar: Optional[str] = None
    description_en: Optional[str] = None
    description_ar: Optional[str] = None


class ContentCreateRequest(BaseModel):
    category_id: Optional[int] = None
    slug: Optional[str] = None
    content_type: str = "lesson"
    status: str = "draft"
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    body_en: Optional[str] = None
    body_ar: Optional[str] = None
    thumbnail_url: Optional[str] = None
    video_url: Optional[str] = None
    video_provider: Optional[str] = None
    video_public_id: Optional[str] = None
    video_duration_seconds: Optional[int] = None
    age_group: Optional[str] = None
    metadata_json: Optional[dict[str, Any]] = None


class ContentUpdateRequest(BaseModel):
    category_id: Optional[int] = None
    slug: Optional[str] = None
    content_type: Optional[str] = None
    status: Optional[str] = None
    title_en: Optional[str] = None
    title_ar: Optional[str] = None
    description_en: Optional[str] = None
    description_ar: Optional[str] = None
    body_en: Optional[str] = None
    body_ar: Optional[str] = None
    thumbnail_url: Optional[str] = None
    video_url: Optional[str] = None
    video_provider: Optional[str] = None
    video_public_id: Optional[str] = None
    video_duration_seconds: Optional[int] = None
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


def _error(detail: str, status_code: int = 400) -> HTTPException:
    return HTTPException(status_code=status_code, detail=detail)


def _trim_or_none(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed if trimmed else None


def _require_text(value: Optional[str], field_label: str) -> str:
    trimmed = _trim_or_none(value)
    if trimmed is None:
        raise _error(f"{field_label} is required")
    return trimmed


def _normalize_status(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in CONTENT_STATUSES:
        raise _error("Status must be draft, ready, review, published, or archived")
    return normalized


def _normalize_content_type(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    normalized = value.strip().lower()
    if normalized not in CONTENT_TYPES:
        raise _error("Content type must be lesson, story, video, activity, or page")
    return normalized


def _normalize_axis_key_or_error(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    trimmed = value.strip()
    if not trimmed:
        return None
    try:
        return normalize_content_axis_key(trimmed)
    except ValueError as exc:
        raise _error(str(exc))


def _validate_thumbnail_url(value: Optional[str]) -> Optional[str]:
    trimmed = _trim_or_none(value)
    if trimmed is None:
        return None
    parsed = urlparse(trimmed)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise _error("Thumbnail URL must be a valid http or https URL")
    return trimmed


def _validate_video_url(value: Optional[str]) -> Optional[str]:
    trimmed = _trim_or_none(value)
    if trimmed is None:
        return None
    parsed = urlparse(trimmed)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise _error("Video URL must be a valid http or https URL")
    return trimmed


def _validate_video_provider(value: Optional[str]) -> Optional[str]:
    trimmed = _trim_or_none(value)
    if trimmed is None:
        return None
    return trimmed.lower()


def _validate_video_public_id(value: Optional[str]) -> Optional[str]:
    return _trim_or_none(value)


def _validate_video_duration_seconds(value: Optional[int]) -> Optional[int]:
    if value is None:
        return None
    if value < 0:
        raise _error("Video duration must not be negative")
    return value


def _validate_age_group(value: Optional[str]) -> Optional[str]:
    trimmed = _trim_or_none(value)
    if trimmed is None:
        return None
    if not AGE_GROUP_PATTERN.match(trimmed):
        raise _error("Age group must be in the format 5-7 or 8+")
    return re.sub(r"\s+", "", trimmed)


def _validate_metadata_json(value: Optional[dict[str, Any]]) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise _error("Metadata must be a JSON object")
    return value


def _prompt_for_question(question: dict[str, Any]) -> str | None:
    for key in ("prompt_en", "prompt_ar", "prompt", "question", "title"):
        raw = question.get(key)
        if raw is not None and str(raw).strip():
            return str(raw).strip()
    return None


def _normalize_question_options(question: dict[str, Any]) -> list[Any]:
    raw_options = question.get("options")
    if raw_options is None:
        raw_options = question.get("choices")
    if not isinstance(raw_options, list):
        raise _error("Each quiz question must include an options list")
    normalized = []
    for option in raw_options:
        if isinstance(option, dict):
            label = (
                _trim_or_none(option.get("label_en"))
                or _trim_or_none(option.get("label_ar"))
                or _trim_or_none(option.get("label"))
                or _trim_or_none(option.get("text"))
                or _trim_or_none(option.get("value"))
            )
            if label is None:
                raise _error("Each quiz option must include display text")
            normalized.append(option)
            continue
        if str(option).strip():
            normalized.append(option)
            continue
        raise _error("Quiz options cannot be empty")
    if len(normalized) < 2:
        raise _error("Each quiz question must have at least two options")
    return normalized


def _normalize_correct_index(question: dict[str, Any], option_count: int) -> int:
    raw_value = question.get("correct_index")
    if raw_value is None:
        raw_value = question.get("answer_index")
    if raw_value is None:
        raw_value = question.get("correctAnswerIndex")
    if raw_value is None and question.get("correct_answer") is not None:
        raw_value = question.get("correct_answer")

    try:
        correct_index = int(raw_value)
    except (TypeError, ValueError):
        raise _error("Each quiz question must include a valid correct answer index")

    if correct_index < 0 or correct_index >= option_count:
        raise _error("Correct answer index must match one of the quiz options")
    return correct_index


def _validate_questions_json(
    value: Optional[list[dict[str, Any]]],
    *,
    require_non_empty: bool,
) -> list[dict[str, Any]]:
    questions = value or []
    if require_non_empty and not questions:
        raise _error("Published quizzes must include at least one question")

    for question in questions:
        if not isinstance(question, dict):
            raise _error("Each quiz question must be a JSON object")
        if _prompt_for_question(question) is None:
            raise _error("Each quiz question must include prompt text")
        options = _normalize_question_options(question)
        _normalize_correct_index(question, len(options))
    return questions


def _validate_publishable_content(
    *,
    content_type: Optional[str],
    title_en: Optional[str],
    title_ar: Optional[str],
    body_en: Optional[str],
    body_ar: Optional[str],
    video_url: Optional[str],
) -> None:
    if _trim_or_none(title_en) is None:
        raise _error("Published content must include an English title")
    if _trim_or_none(title_ar) is None:
        raise _error("Published content must include an Arabic title")
    normalized_type = (content_type or "").strip().lower()
    if normalized_type != "video":
        if _trim_or_none(body_en) is None:
            raise _error("Published content must include an English body")
        if _trim_or_none(body_ar) is None:
            raise _error("Published content must include an Arabic body")
    if normalized_type == "video" and _trim_or_none(video_url) is None:
        raise _error("Published video content must include a video URL")


def _normalized_content_media_payload(
    *,
    video_url: Optional[str],
    video_provider: Optional[str],
    video_public_id: Optional[str],
    video_duration_seconds: Optional[int],
    metadata_json: dict[str, Any],
) -> tuple[Optional[str], Optional[str], Optional[str], Optional[int], dict[str, Any]]:
    normalized_metadata = dict(metadata_json or {})
    normalized_video_url = _validate_video_url(video_url or normalized_metadata.get("video_url"))
    normalized_video_provider = _validate_video_provider(
        video_provider or normalized_metadata.get("video_provider")
    )
    normalized_video_public_id = _validate_video_public_id(
        video_public_id or normalized_metadata.get("video_public_id")
    )
    normalized_duration = _validate_video_duration_seconds(
        video_duration_seconds
        if video_duration_seconds is not None
        else normalized_metadata.get("duration_seconds")
    )

    for key in ("video_url", "video_provider", "video_public_id"):
        normalized_metadata.pop(key, None)
    if normalized_video_url is not None:
        normalized_metadata["video_url"] = normalized_video_url
    if normalized_video_provider is not None:
        normalized_metadata["video_provider"] = normalized_video_provider
    if normalized_video_public_id is not None:
        normalized_metadata["video_public_id"] = normalized_video_public_id
    if normalized_duration is not None:
        normalized_metadata["duration_seconds"] = normalized_duration

    return (
        normalized_video_url,
        normalized_video_provider,
        normalized_video_public_id,
        normalized_duration,
        normalized_metadata,
    )


def _ensure_content_media_upload_permission(*, admin, db: Session) -> None:
    for permission_name in ("admin.content.create", "admin.content.edit"):
        try:
            ensure_permission(admin=admin, db=db, permission_name=permission_name)
            return
        except HTTPException:
            continue
    raise HTTPException(
        status_code=403,
        detail={
            "code": "PERMISSION_DENIED",
            "required_any": ["admin.content.create", "admin.content.edit"],
        },
    )


def _categories_query(db: Session):
    return db.query(ContentCategory).options(
        joinedload(ContentCategory.contents),
        joinedload(ContentCategory.quizzes),
    )


def _category_axis_groups(categories: list[ContentCategory]) -> list[dict[str, Any]]:
    grouped: dict[str, list[ContentCategory]] = {key: [] for key in CONTENT_AXIS_METADATA}
    for category in categories:
        axis_key = normalize_content_axis_key(getattr(category, "axis_key", None))
        grouped.setdefault(axis_key, []).append(category)
    return [
        serialize_content_axis_summary(axis_key, categories=grouped.get(axis_key, []))
        for axis_key in CONTENT_AXIS_METADATA
    ]


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
    quiz = _quizzes_query(db).filter(Quiz.id == quiz_id, Quiz.deleted_at.is_(None)).first()
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


def _ensure_content_slug_available(
    *,
    slug: str,
    db: Session,
    exclude_content_id: Optional[int] = None,
) -> None:
    query = db.query(ContentItem).filter(func.lower(ContentItem.slug) == slug.lower())
    if exclude_content_id is not None:
        query = query.filter(ContentItem.id != exclude_content_id)
    duplicate = query.first()
    if duplicate is not None:
        raise _error("Content slug already exists")


@router.get("/admin/categories")
def list_categories(
    axis_key: str = Query(""),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.view")),
):
    query = _categories_query(db).filter(ContentCategory.deleted_at.is_(None))
    normalized_axis_key = None
    if axis_key.strip():
        normalized_axis_key = _normalize_axis_key_or_error(axis_key)
        query = query.filter(ContentCategory.axis_key == normalized_axis_key)
    items = query.order_by(ContentCategory.axis_key.asc(), func.lower(ContentCategory.title_en)).all()
    all_categories = (
        _categories_query(db)
        .filter(ContentCategory.deleted_at.is_(None))
        .order_by(ContentCategory.axis_key.asc(), func.lower(ContentCategory.title_en))
        .all()
    )
    return {
        "items": [serialize_content_category(item) for item in items],
        "axes": _category_axis_groups(all_categories),
        "filters": {"axis_key": normalized_axis_key},
    }


@router.post("/admin/categories")
def create_category(
    payload: CategoryCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.create")),
):
    axis_key = _normalize_axis_key_or_error(payload.axis_key)
    if axis_key is None:
        raise _error("Axis key is required")
    title_en = _require_text(payload.title_en, "English title")
    title_ar = _require_text(payload.title_ar, "Arabic title")
    slug = _slugify(payload.slug or title_en)
    if not slug:
        raise _error("Category slug is required")

    duplicate = db.query(ContentCategory).filter(func.lower(ContentCategory.slug) == slug).first()
    if duplicate is not None:
        raise _error("Category slug already exists")

    category = ContentCategory(
        axis_key=axis_key,
        slug=slug,
        title_en=title_en,
        title_ar=title_ar,
        description_en=_trim_or_none(payload.description_en),
        description_ar=_trim_or_none(payload.description_ar),
        created_by=admin.id,
        updated_by=admin.id,
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
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

    if payload.axis_key is not None:
        category.axis_key = _normalize_axis_key_or_error(payload.axis_key) or category.axis_key
    if payload.slug is not None:
        slug = _slugify(payload.slug)
        if not slug:
            raise _error("Category slug is required")
        duplicate = (
            db.query(ContentCategory)
            .filter(func.lower(ContentCategory.slug) == slug, ContentCategory.id != category.id)
            .first()
        )
        if duplicate is not None:
            raise _error("Category slug already exists")
        category.slug = slug

    if payload.title_en is not None:
        category.title_en = _require_text(payload.title_en, "English title")
    if payload.title_ar is not None:
        category.title_ar = _require_text(payload.title_ar, "Arabic title")
    if payload.description_en is not None:
        category.description_en = _trim_or_none(payload.description_en)
    if payload.description_ar is not None:
        category.description_ar = _trim_or_none(payload.description_ar)

    category.updated_by = admin.id
    category.updated_at = db_utc_now()
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
    require_sensitive_action_confirmation(request, action="category.delete")
    category = _get_category_or_404(category_id, db)
    active_contents = [item for item in (category.contents or []) if item.deleted_at is None]
    active_quizzes = [item for item in (category.quizzes or []) if item.deleted_at is None]
    if active_contents or active_quizzes:
        raise _error("Cannot delete a category that still has content or quizzes")

    before = serialize_content_category(category)
    category.deleted_at = db_utc_now()
    category.updated_by = admin.id
    category.updated_at = db_utc_now()
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
    emit_event(
        "cms.category.deleted",
        category="cms",
        admin_id=admin.id,
        category_id=category.id,
        slug=category.slug,
    )
    return {"success": True}


@router.get("/admin/contents")
def list_contents(
    search: str = Query("", description="Search titles"),
    status_filter: str = Query("", alias="status"),
    slug: str = Query(""),
    category_id: Optional[int] = Query(None),
    axis_key: str = Query(""),
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
            func.lower(ContentItem.slug).like(term)
            | func.lower(func.coalesce(ContentItem.title_en, "")).like(term)
            | func.lower(func.coalesce(ContentItem.title_ar, "")).like(term)
            | func.lower(func.coalesce(ContentItem.description_en, "")).like(term)
            | func.lower(func.coalesce(ContentItem.description_ar, "")).like(term)
        )
    if slug.strip():
        query = query.filter(func.lower(ContentItem.slug) == slug.strip().lower())
    if status_filter.strip():
        query = query.filter(ContentItem.status == _normalize_status(status_filter))
    if category_id is not None:
        query = query.filter(ContentItem.category_id == category_id)
    normalized_axis_key = None
    if axis_key.strip():
        normalized_axis_key = _normalize_axis_key_or_error(axis_key)
        query = query.join(ContentItem.category).filter(
            ContentCategory.axis_key == normalized_axis_key,
            ContentCategory.deleted_at.is_(None),
        )
    if content_type.strip():
        query = query.filter(ContentItem.content_type == _normalize_content_type(content_type))

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
            "slug": slug.strip().lower(),
            "status": status_filter.strip().lower(),
            "category_id": category_id,
            "axis_key": normalized_axis_key,
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


@router.post("/admin/media/videos/upload")
async def upload_admin_content_video(
    request: Request,
    file: UploadFile = File(...),
    axis_key: str | None = Form(default=None),
    category_slug: str | None = Form(default=None),
    content_slug: str | None = Form(default=None),
    db: Session = Depends(get_db),
    admin=Depends(get_current_admin),
):
    _ensure_content_media_upload_permission(admin=admin, db=db)
    filename = (file.filename or "video").strip() or "video"
    mime_type = (file.content_type or "").strip().lower()
    if mime_type and not mime_type.startswith("video/"):
        raise _error("Uploaded file must be a video", status_code=415)

    file_bytes = await file.read()
    max_bytes = settings.media_max_upload_size_mb * 1024 * 1024
    if len(file_bytes) > max_bytes:
        raise _error(
            f"Uploaded video exceeds the {settings.media_max_upload_size_mb} MB limit",
            status_code=413,
        )

    normalized_axis_key = _normalize_axis_key_or_error(axis_key)
    try:
        asset = media_service.upload_video(
            file_bytes=file_bytes,
            filename=filename,
            axis_key=normalized_axis_key,
            category_slug=_trim_or_none(category_slug),
            content_slug=_trim_or_none(content_slug),
            mime_type=mime_type or None,
        )
    except MediaServiceError as exc:
        raise _error(str(exc), status_code=503) from exc

    payload = asset.to_payload()
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="content.media.upload",
        entity_type="content_media",
        entity_id=asset.public_id,
        after_json=payload,
    )
    db.commit()
    emit_event(
        "cms.content.video_uploaded",
        category="cms",
        admin_id=admin.id,
        axis_key=normalized_axis_key,
        public_id=asset.public_id,
        provider=asset.provider,
    )
    return {"success": True, "item": payload}


@router.post("/admin/contents")
def create_content(
    payload: ContentCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.create")),
):
    _ensure_category_exists(payload.category_id, db)

    content_type = _normalize_content_type(payload.content_type)
    status_value = _normalize_status(payload.status)
    title_en = _require_text(payload.title_en, "English title")
    title_ar = _require_text(payload.title_ar, "Arabic title")
    slug = _slugify(payload.slug or title_en)
    if not slug:
        raise _error("Content slug is required")
    _ensure_content_slug_available(slug=slug, db=db)
    description_en = _trim_or_none(payload.description_en)
    description_ar = _trim_or_none(payload.description_ar)
    body_en = _trim_or_none(payload.body_en)
    body_ar = _trim_or_none(payload.body_ar)
    thumbnail_url = _validate_thumbnail_url(payload.thumbnail_url)
    age_group = _validate_age_group(payload.age_group)
    metadata_json = _validate_metadata_json(payload.metadata_json)
    (
        video_url,
        video_provider,
        video_public_id,
        video_duration_seconds,
        metadata_json,
    ) = _normalized_content_media_payload(
        video_url=payload.video_url,
        video_provider=payload.video_provider,
        video_public_id=payload.video_public_id,
        video_duration_seconds=payload.video_duration_seconds,
        metadata_json=metadata_json,
    )

    if status_value == PUBLISHED_STATUS:
        _validate_publishable_content(
            content_type=content_type,
            title_en=title_en,
            title_ar=title_ar,
            body_en=body_en,
            body_ar=body_ar,
            video_url=video_url,
        )

    content = ContentItem(
        category_id=payload.category_id,
        slug=slug,
        content_type=content_type or "lesson",
        status=status_value,
        title_en=title_en,
        title_ar=title_ar,
        description_en=description_en,
        description_ar=description_ar,
        body_en=body_en,
        body_ar=body_ar,
        thumbnail_url=thumbnail_url,
        video_url=video_url,
        video_provider=video_provider,
        video_public_id=video_public_id,
        video_duration_seconds=video_duration_seconds,
        age_group=age_group,
        metadata_json=metadata_json,
        created_by=admin.id,
        updated_by=admin.id,
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
        published_at=db_utc_now() if status_value == PUBLISHED_STATUS else None,
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
    if payload.slug is not None:
        slug = _slugify(payload.slug)
        if not slug:
            raise _error("Content slug is required")
        _ensure_content_slug_available(slug=slug, db=db, exclude_content_id=content.id)
        content.slug = slug
    if payload.content_type is not None:
        content.content_type = _normalize_content_type(payload.content_type) or content.content_type
    if payload.status is not None:
        content.status = _normalize_status(payload.status)
    if payload.title_en is not None:
        content.title_en = _require_text(payload.title_en, "English title")
    if payload.title_ar is not None:
        content.title_ar = _require_text(payload.title_ar, "Arabic title")
    if payload.description_en is not None:
        content.description_en = _trim_or_none(payload.description_en)
    if payload.description_ar is not None:
        content.description_ar = _trim_or_none(payload.description_ar)
    if payload.body_en is not None:
        content.body_en = _trim_or_none(payload.body_en)
    if payload.body_ar is not None:
        content.body_ar = _trim_or_none(payload.body_ar)
    if payload.thumbnail_url is not None:
        content.thumbnail_url = _validate_thumbnail_url(payload.thumbnail_url)
    if payload.video_url is not None:
        content.video_url = _validate_video_url(payload.video_url)
    if payload.video_provider is not None:
        content.video_provider = _validate_video_provider(payload.video_provider)
    if payload.video_public_id is not None:
        content.video_public_id = _validate_video_public_id(payload.video_public_id)
    if payload.video_duration_seconds is not None:
        content.video_duration_seconds = _validate_video_duration_seconds(
            payload.video_duration_seconds
        )
    if payload.age_group is not None:
        content.age_group = _validate_age_group(payload.age_group)
    if payload.metadata_json is not None:
        content.metadata_json = _validate_metadata_json(payload.metadata_json)
    (
        content.video_url,
        content.video_provider,
        content.video_public_id,
        content.video_duration_seconds,
        content.metadata_json,
    ) = _normalized_content_media_payload(
        video_url=content.video_url,
        video_provider=content.video_provider,
        video_public_id=content.video_public_id,
        video_duration_seconds=content.video_duration_seconds,
        metadata_json=content.metadata_json or {},
    )

    if content.status == PUBLISHED_STATUS:
        _validate_publishable_content(
            content_type=content.content_type,
            title_en=content.title_en,
            title_ar=content.title_ar,
            body_en=content.body_en,
            body_ar=content.body_ar,
            video_url=content.video_url,
        )
        content.published_at = content.published_at or db_utc_now()
    else:
        content.published_at = None

    content.updated_by = admin.id
    content.updated_at = db_utc_now()
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
    require_sensitive_action_confirmation(request, action="content.publish")
    content = _get_content_or_404(content_id, db)
    _validate_publishable_content(
        content_type=content.content_type,
        title_en=content.title_en,
        title_ar=content.title_ar,
        body_en=content.body_en,
        body_ar=content.body_ar,
        video_url=content.video_url,
    )

    before = serialize_content_item(content, include_quizzes=True)
    content.status = PUBLISHED_STATUS
    content.published_at = db_utc_now()
    content.updated_by = admin.id
    content.updated_at = db_utc_now()
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
    emit_event(
        "cms.content.published",
        category="cms",
        admin_id=admin.id,
        content_id=content.id,
        slug=content.slug,
        content_type=content.content_type,
    )
    return {"success": True, "item": serialize_content_item(content, include_quizzes=True)}


@router.post("/admin/contents/{content_id}/unpublish")
def unpublish_content(
    content_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.publish")),
):
    require_sensitive_action_confirmation(request, action="content.unpublish")
    content = _get_content_or_404(content_id, db)
    before = serialize_content_item(content, include_quizzes=True)
    content.status = READY_STATUS
    content.published_at = None
    content.updated_by = admin.id
    content.updated_at = db_utc_now()
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
    emit_event(
        "cms.content.unpublished",
        category="cms",
        admin_id=admin.id,
        content_id=content.id,
        slug=content.slug,
        content_type=content.content_type,
    )
    return {"success": True, "item": serialize_content_item(content, include_quizzes=True)}


@router.delete("/admin/contents/{content_id}")
def delete_content(
    content_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.content.delete")),
):
    require_sensitive_action_confirmation(request, action="content.delete")
    content = _get_content_or_404(content_id, db)
    before = serialize_content_item(content, include_quizzes=True)
    content.deleted_at = db_utc_now()
    content.updated_by = admin.id
    content.updated_at = db_utc_now()
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
    emit_event(
        "cms.content.deleted",
        category="cms",
        admin_id=admin.id,
        content_id=content.id,
        slug=content.slug,
        content_type=content.content_type,
    )
    return {"success": True}


@router.get("/admin/quizzes")
def list_quizzes(
    status_filter: str = Query("", alias="status"),
    category_id: Optional[int] = Query(None),
    axis_key: str = Query(""),
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
    normalized_axis_key = None
    if axis_key.strip():
        normalized_axis_key = _normalize_axis_key_or_error(axis_key)
        query = query.join(Quiz.category).filter(
            ContentCategory.axis_key == normalized_axis_key,
            ContentCategory.deleted_at.is_(None),
        )
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
        "filters": {
            "status": status_filter.strip().lower(),
            "category_id": category_id,
            "axis_key": normalized_axis_key,
            "content_id": content_id,
        },
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
    title_en = _require_text(payload.title_en, "English title")
    title_ar = _require_text(payload.title_ar, "Arabic title")
    questions_json = _validate_questions_json(
        payload.questions_json,
        require_non_empty=status_value == "published",
    )

    quiz = Quiz(
        content_id=payload.content_id,
        category_id=payload.category_id,
        status=status_value,
        title_en=title_en,
        title_ar=title_ar,
        description_en=_trim_or_none(payload.description_en),
        description_ar=_trim_or_none(payload.description_ar),
        questions_json=questions_json,
        created_by=admin.id,
        updated_by=admin.id,
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
        published_at=db_utc_now() if status_value == "published" else None,
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
    if payload.title_en is not None:
        quiz.title_en = _require_text(payload.title_en, "English title")
    if payload.title_ar is not None:
        quiz.title_ar = _require_text(payload.title_ar, "Arabic title")
    if payload.description_en is not None:
        quiz.description_en = _trim_or_none(payload.description_en)
    if payload.description_ar is not None:
        quiz.description_ar = _trim_or_none(payload.description_ar)
    if payload.questions_json is not None:
        quiz.questions_json = _validate_questions_json(
            payload.questions_json,
            require_non_empty=False,
        )

    if quiz.status == "published":
        _validate_questions_json(quiz.questions_json, require_non_empty=True)
        quiz.published_at = quiz.published_at or db_utc_now()
    else:
        quiz.published_at = None

    quiz.updated_by = admin.id
    quiz.updated_at = db_utc_now()
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
    require_sensitive_action_confirmation(request, action="quiz.delete")
    quiz = _get_quiz_or_404(quiz_id, db)
    before = serialize_quiz(quiz)
    quiz.deleted_at = db_utc_now()
    quiz.updated_by = admin.id
    quiz.updated_at = db_utc_now()
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
    emit_event(
        "cms.quiz.deleted",
        category="cms",
        admin_id=admin.id,
        quiz_id=quiz.id,
        title=quiz.title_en,
    )
    return {"success": True}

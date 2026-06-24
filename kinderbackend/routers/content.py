from __future__ import annotations

import asyncio
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from admin_utils import normalize_content_axis_key, serialize_content_axis_summary
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

_LEGAL_DEFAULT_CONTENT: dict[str, dict[str, str]] = {
    "terms": {
        "title_en": "Terms of Service",
        "title_ar": "شروط الخدمة",
        "body_en": (
            "These terms explain how Kinder World should be used by parents, guardians, "
            "and children under adult supervision.\n\n"
            "Parents are responsible for the account, subscription choices, and the child "
            "profiles created under that account. Please keep login credentials, PINs, and "
            "any linked payment methods secure.\n\n"
            "Kinder World content is intended for guided educational and entertainment use. "
            "You may not copy, resell, scrape, reverse engineer, or misuse the service or "
            "its content.\n\n"
            "We may update features, content catalogs, and subscription benefits over time. "
            "If a change materially affects service terms, the latest published version "
            "inside the app or backend legal endpoint should be treated as the current "
            "reference.\n\n"
            "If you continue using the service after updates are published, that continued "
            "use counts as acceptance of the updated terms."
        ),
        "body_ar": (
            "توضح هذه الشروط كيفية استخدام Kinder World من قبل الوالدين أو الأوصياء، "
            "مع استخدام الأطفال للتطبيق تحت إشراف بالغ.\n\n"
            "يكون ولي الأمر مسؤولًا عن الحساب وخيارات الاشتراك وملفات الأطفال المرتبطة به. "
            "يجب الحفاظ على بيانات الدخول ورمز PIN ووسائل الدفع المرتبطة بشكل آمن.\n\n"
            "تم تصميم محتوى Kinder World للاستخدام التعليمي والترفيهي الموجّه. لا يجوز "
            "نسخ الخدمة أو إعادة بيعها أو جمع محتواها آليًا أو إساءة استخدامها بأي شكل.\n\n"
            "قد نقوم بتحديث الميزات والمحتوى ومزايا الاشتراك مع الوقت. وعند وجود تغيير "
            "مؤثر، تُعد النسخة المنشورة عبر التطبيق أو نقطة النهاية القانونية في الخلفية "
            "هي المرجع الأحدث.\n\n"
            "استمرارك في استخدام الخدمة بعد نشر التحديثات يعني موافقتك على الشروط المحدثة."
        ),
    },
    "privacy": {
        "title_en": "Privacy Policy",
        "title_ar": "سياسة الخصوصية",
        "body_en": (
            "Kinder World collects only the information needed to provide accounts, child "
            "profiles, learning progress, subscriptions, and support.\n\n"
            "Parent account information may include email, authentication details, "
            "subscription status, and support history. Child profile information may include "
            "display name, avatar, learning activity, preferences, and progress metrics.\n\n"
            "We use this information to keep the app working, personalize age-appropriate "
            "content, protect accounts, and improve reliability. We do not treat child data "
            "as a source for advertising profiles.\n\n"
            "Where caching or offline storage is enabled, some content and profile "
            "information may be stored locally on the device to keep the experience working "
            "during connectivity issues.\n\n"
            "If you need to update or remove account-related information, use the available "
            "in-app controls or contact support through the parent-facing help channels."
        ),
        "body_ar": (
            "يجمع Kinder World فقط البيانات اللازمة لتشغيل الحسابات وملفات الأطفال "
            "والتقدم التعليمي والاشتراكات والدعم.\n\n"
            "قد تتضمن بيانات حساب ولي الأمر البريد الإلكتروني وبيانات التحقق وحالة "
            "الاشتراك وسجل الدعم. وقد تتضمن بيانات ملف الطفل الاسم الظاهر والصورة الرمزية "
            "والنشاط التعليمي والتفضيلات ومؤشرات التقدم.\n\n"
            "نستخدم هذه البيانات لتشغيل التطبيق وتخصيص محتوى مناسب للعمر وحماية الحسابات "
            "وتحسين الاعتمادية. ولا نستخدم بيانات الأطفال لبناء ملفات إعلانية.\n\n"
            "عند تفعيل التخزين المؤقت أو العمل دون اتصال، قد تُحفظ بعض البيانات محليًا "
            "على الجهاز لضمان استمرار التجربة عند ضعف الاتصال.\n\n"
            "إذا احتجت إلى تحديث بيانات الحساب أو حذفها، فاستخدم الأدوات المتاحة داخل "
            "التطبيق أو تواصل مع الدعم من خلال قنوات المساعدة الخاصة بولي الأمر."
        ),
    },
    "coppa": {
        "title_en": "COPPA Compliance",
        "title_ar": "امتثال COPPA",
        "body_en": (
            "Kinder World is designed for child-facing use under verified parent or guardian "
            "control.\n\n"
            "Child profiles are created and managed from the parent side of the app. Parents "
            "decide what child information is provided, which profiles remain active, and how "
            "subscriptions or safety settings are configured.\n\n"
            "We limit child profile data to the information required to deliver educational "
            "content, save progress, and enforce safety or access rules. Parent-facing "
            "controls are used for account recovery, subscription management, and support "
            "requests.\n\n"
            "If COPPA-specific disclosures or consent text are published from the backend, "
            "that published version should be treated as the authoritative legal copy for "
            "production use.\n\n"
            "Parents who need help with review, correction, or deletion requests should use "
            "the in-app support and legal contact paths available in the parent experience."
        ),
        "body_ar": (
            "تم تصميم Kinder World لاستخدام الأطفال تحت إشراف وتحكم ولي أمر أو وصي موثّق.\n\n"
            "يتم إنشاء ملفات الأطفال وإدارتها من جهة ولي الأمر داخل التطبيق. ويحدد ولي "
            "الأمر البيانات المقدمة لكل طفل، والملفات النشطة، وإعدادات الاشتراك والسلامة.\n\n"
            "نقصر بيانات ملف الطفل على ما يلزم لتقديم المحتوى التعليمي وحفظ التقدم وتطبيق "
            "قواعد السلامة والوصول. كما تُستخدم أدوات ولي الأمر لاستعادة الحساب وإدارة "
            "الاشتراك وطلبات الدعم.\n\n"
            "إذا تم نشر إفصاحات أو نصوص موافقة خاصة بـ COPPA من خلال الخلفية، فتُعد "
            "النسخة المنشورة هناك هي المرجع القانوني المعتمد في بيئة الإنتاج.\n\n"
            "يمكن لولي الأمر استخدام مسارات الدعم والاتصال القانوني داخل تجربة الوالدين "
            "لطلبات المراجعة أو التصحيح أو الحذف."
        ),
    },
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
    axis_key = normalize_content_axis_key(getattr(category, "axis_key", None))
    return {
        "id": category.id,
        "axis_key": axis_key,
        "axis": serialize_content_axis_summary(axis_key),
        "slug": category.slug,
        "title_en": category.title_en,
        "title_ar": category.title_ar,
        "description_en": category.description_en,
        "description_ar": category.description_ar,
        "content_count": len(active_contents),
        "quiz_count": len(active_quizzes),
    }


def _serialize_public_quiz(quiz: Quiz) -> dict[str, Any]:
    axis_key = None
    if quiz.category is not None:
        axis_key = normalize_content_axis_key(getattr(quiz.category, "axis_key", None))
    return {
        "id": quiz.id,
        "content_id": quiz.content_id,
        "category_id": quiz.category_id,
        "axis_key": axis_key,
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
    axis_key = None
    if content.category is not None:
        axis_key = normalize_content_axis_key(getattr(content.category, "axis_key", None))
    payload = {
        "id": content.id,
        "slug": content.slug,
        "category_id": content.category_id,
        "axis_key": axis_key,
        "content_type": content.content_type,
        "title_en": content.title_en,
        "title_ar": content.title_ar,
        "description_en": content.description_en,
        "description_ar": content.description_ar,
        "body_en": content.body_en,
        "body_ar": content.body_ar,
        "thumbnail_url": content.thumbnail_url,
        "video_url": getattr(content, "video_url", None),
        "video_provider": getattr(content, "video_provider", None),
        "video_public_id": getattr(content, "video_public_id", None),
        "video_duration_seconds": getattr(content, "video_duration_seconds", None),
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
            if quiz.deleted_at is None
            and quiz.status == "published"
            and quiz.published_at is not None
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


def _get_published_page(*, db: Session, slug: str) -> ContentItem | None:
    return (
        _published_content_query(db)
        .filter(ContentItem.content_type == "page", ContentItem.slug == slug.lower())
        .first()
    )


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
        question = str(
            item.get("question") or question_en or question_ar or item.get("title") or ""
        ).strip()
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
    page = _get_published_page(db=db, slug=PUBLIC_PAGE_SLUGS["faq"])
    if page is None:
        return {
            "title": "FAQ",
            "body": "",
            "items": [],
            "item": None,
        }
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


def _legal_response(*, db: Session, key: str) -> dict[str, Any]:
    page = _get_published_page(db=db, slug=PUBLIC_PAGE_SLUGS[key])
    defaults = _LEGAL_DEFAULT_CONTENT[key]
    if page is not None:
        body_en = (page.body_en or "").strip() or defaults["body_en"]
        body_ar = (page.body_ar or "").strip() or defaults["body_ar"]
        return {
            "body": body_en,
            "body_en": body_en,
            "body_ar": body_ar,
            "content": body_en,
            "item": _serialize_public_content_item(page),
        }
    return {
        "body": defaults["body_en"],
        "body_en": defaults["body_en"],
        "body_ar": defaults["body_ar"],
        "content": defaults["body_en"],
        "item": None,
    }


@router.get("/legal/terms")
def terms(db: Session = Depends(get_db)):
    return _legal_response(db=db, key="terms")


@router.get("/legal/privacy")
def privacy(db: Session = Depends(get_db)):
    return _legal_response(db=db, key="privacy")


@router.get("/legal/coppa")
def coppa(db: Session = Depends(get_db)):
    return _legal_response(db=db, key="coppa")


@router.get("/content/child/categories")
async def list_child_content_categories(db: Session = Depends(get_db)):
    # Child-home landing query: eager-loads every category with its contents and
    # quizzes. Run it off the event loop so it doesn't block concurrent requests.
    def _build() -> dict[str, Any]:
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

    return await asyncio.to_thread(_build)


@router.get("/content/child/items")
def list_child_content_items(
    category_slug: str | None = None,
    content_type: str | None = None,
    age: int | None = None,
    search: str | None = None,
    page: int = Query(1, ge=1),
    limit: int = Query(200, ge=1, le=500),
    db: Session = Depends(get_db),
):
    query = _published_content_query(db).filter(
        ContentItem.content_type.in_(PUBLIC_CHILD_CONTENT_TYPES)
    )

    if category_slug:
        query = query.join(ContentItem.category).filter(
            ContentCategory.slug == category_slug.lower()
        )
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

    if age is not None:
        # Range-check against the structured min_age/max_age columns. NULL on
        # either bound means "unbounded" on that side (treated as all ages), so
        # legacy rows that only ever had a free-text age_group still match.
        query = query.filter(
            or_(ContentItem.min_age.is_(None), ContentItem.min_age <= age),
            or_(ContentItem.max_age.is_(None), ContentItem.max_age >= age),
        )

    # Count and paginate at the database level so we never materialize the whole
    # published catalog into memory just to slice one page out of it.
    total = query.count()
    page_items = (
        query.order_by(ContentItem.published_at.desc(), ContentItem.id.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )

    return {
        "items": [
            _serialize_public_content_item(item, include_quizzes=True) for item in page_items
        ],
        "page": page,
        "limit": limit,
        "total": total,
    }


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
    page: int = Query(1, ge=1),
    limit: int = Query(200, ge=1, le=500),
    db: Session = Depends(get_db),
):
    query = _published_quiz_query(db)
    if category_slug:
        query = query.join(Quiz.category).filter(ContentCategory.slug == category_slug.lower())
    if content_slug:
        query = query.join(Quiz.content).filter(ContentItem.slug == content_slug.lower())

    total = query.count()
    items = (
        query.order_by(Quiz.published_at.desc(), Quiz.id.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )
    return {
        "items": [_serialize_public_quiz(item) for item in items],
        "page": page,
        "limit": limit,
        "total": total,
    }

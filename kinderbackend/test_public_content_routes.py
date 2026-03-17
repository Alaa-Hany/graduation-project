from core.time_utils import db_utc_now
from models import ContentCategory, ContentItem, Quiz


def _create_category(db, *, slug: str, title_en: str, title_ar: str):
    category = ContentCategory(
        slug=slug,
        title_en=title_en,
        title_ar=title_ar,
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def _create_content(
    db,
    *,
    slug: str,
    title_en: str,
    title_ar: str,
    content_type: str,
    category_id: int | None = None,
    body_en: str | None = None,
    metadata_json: dict | None = None,
    age_group: str | None = None,
):
    content = ContentItem(
        slug=slug,
        category_id=category_id,
        content_type=content_type,
        status="published",
        title_en=title_en,
        title_ar=title_ar,
        body_en=body_en,
        body_ar=body_en,
        metadata_json=metadata_json or {},
        age_group=age_group,
        published_at=db_utc_now(),
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(content)
    db.commit()
    db.refresh(content)
    return content


def _create_quiz(db, *, content_id: int, category_id: int, title_en: str):
    quiz = Quiz(
        content_id=content_id,
        category_id=category_id,
        status="published",
        title_en=title_en,
        title_ar=title_en,
        description_en="Quiz description",
        description_ar="Quiz description",
        questions_json=[
            {
                "prompt_en": "What color is the sky?",
                "options": ["Blue", "Green"],
                "correct_index": 0,
            }
        ],
        published_at=db_utc_now(),
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(quiz)
    db.commit()
    db.refresh(quiz)
    return quiz


def test_public_about_and_legal_pages_are_backed_by_published_cms_content(client, db):
    _create_content(
        db,
        slug="about",
        title_en="About Kinder",
        title_ar="About Kinder",
        content_type="page",
        body_en="About page body from CMS",
    )
    _create_content(
        db,
        slug="legal-terms",
        title_en="Terms",
        title_ar="Terms",
        content_type="page",
        body_en="Terms body from CMS",
    )

    about_response = client.get("/content/about")
    assert about_response.status_code == 200
    about_payload = about_response.json()
    assert about_payload["body"] == "About page body from CMS"
    assert about_payload["item"]["slug"] == "about"

    legal_response = client.get("/legal/terms")
    assert legal_response.status_code == 200
    legal_payload = legal_response.json()
    assert legal_payload["body"] == "Terms body from CMS"
    assert legal_payload["content"] == "Terms body from CMS"
    assert legal_payload["item"]["slug"] == "legal-terms"


def test_public_help_faq_reads_structured_items_from_page_metadata(client, db):
    _create_content(
        db,
        slug="help-faq",
        title_en="FAQ",
        title_ar="FAQ",
        content_type="page",
        body_en="FAQ body",
        metadata_json={
            "faq_items": [
                {
                    "id": "faq-1",
                    "question": "How do I add a child profile?",
                    "answer": "Open parent dashboard and create one.",
                },
                {
                    "id": "faq-2",
                    "question_en": "What if I forget the picture password?",
                    "answer_en": "Reset it from parent mode.",
                },
            ]
        },
    )

    response = client.get("/content/help-faq")

    assert response.status_code == 200
    payload = response.json()
    assert payload["item"]["slug"] == "help-faq"
    assert len(payload["items"]) == 2
    assert payload["items"][0]["id"] == "faq-1"
    assert payload["items"][1]["question"] == "What if I forget the picture password?"


def test_child_content_public_endpoints_return_only_published_child_content(client, db):
    category = _create_category(
        db,
        slug="educational",
        title_en="Educational",
        title_ar="Educational",
    )
    published = _create_content(
        db,
        slug="math-basics",
        title_en="Math Basics",
        title_ar="Math Basics",
        content_type="lesson",
        category_id=category.id,
        body_en="Math lesson body",
        age_group="5-7",
    )
    _create_quiz(
        db,
        content_id=published.id,
        category_id=category.id,
        title_en="Math Basics Quiz",
    )
    draft = ContentItem(
        slug="draft-story",
        category_id=category.id,
        content_type="story",
        status="draft",
        title_en="Draft Story",
        title_ar="Draft Story",
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(draft)
    db.commit()

    categories_response = client.get("/content/child/categories")
    assert categories_response.status_code == 200
    categories_payload = categories_response.json()
    assert [item["slug"] for item in categories_payload["items"]] == ["educational"]

    items_response = client.get("/content/child/items", params={"category_slug": "educational"})
    assert items_response.status_code == 200
    items_payload = items_response.json()
    assert len(items_payload["items"]) == 1
    assert items_payload["items"][0]["slug"] == "math-basics"
    assert items_payload["items"][0]["quizzes"][0]["title_en"] == "Math Basics Quiz"

    detail_response = client.get("/content/child/items/math-basics")
    assert detail_response.status_code == 200
    detail_payload = detail_response.json()
    assert detail_payload["item"]["slug"] == "math-basics"

    age_filtered = client.get("/content/child/items", params={"age": 9})
    assert age_filtered.status_code == 200
    assert age_filtered.json()["items"] == []

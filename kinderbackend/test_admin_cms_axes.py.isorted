from core.time_utils import db_utc_now
from models import ContentCategory, ContentItem


def _create_category(db, *, slug: str, axis_key: str, title_en: str):
    category = ContentCategory(
        axis_key=axis_key,
        slug=slug,
        title_en=title_en,
        title_ar=title_en,
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def _create_content(db, *, slug: str, category_id: int, title_en: str):
    content = ContentItem(
        category_id=category_id,
        slug=slug,
        content_type="lesson",
        status="published",
        title_en=title_en,
        title_ar=title_en,
        body_en="Body",
        body_ar="Body",
        published_at=db_utc_now(),
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(content)
    db.commit()
    db.refresh(content)
    return content


def test_admin_cms_categories_and_content_are_grouped_by_axis(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(
        email="cms.axes.admin@example.com",
        role_names=["super_admin"],
    )
    educational = _create_category(
        db,
        slug="educational-math",
        axis_key="educational",
        title_en="Educational Math",
    )
    behavioral = _create_category(
        db,
        slug="behavioral-values",
        axis_key="behavioral",
        title_en="Behavioral Values",
    )
    _create_content(
        db,
        slug="math-basics",
        category_id=educational.id,
        title_en="Math Basics",
    )
    _create_content(
        db,
        slug="kindness-basics",
        category_id=behavioral.id,
        title_en="Kindness Basics",
    )

    categories_response = client.get(
        "/admin/categories",
        headers=admin_headers(admin),
    )
    assert categories_response.status_code == 200
    categories_payload = categories_response.json()
    assert {item["axis_key"] for item in categories_payload["items"]} == {
        "educational",
        "behavioral",
    }
    axes = {item["key"]: item for item in categories_payload["axes"]}
    assert set(axes) == {"behavioral", "educational", "skillful", "entertaining"}
    assert axes["educational"]["content_count"] == 1
    assert axes["behavioral"]["content_count"] == 1

    contents_response = client.get(
        "/admin/contents",
        params={"axis_key": "educational"},
        headers=admin_headers(admin),
    )
    assert contents_response.status_code == 200
    items = contents_response.json()["items"]
    assert [item["slug"] for item in items] == ["math-basics"]
    assert items[0]["axis_key"] == "educational"

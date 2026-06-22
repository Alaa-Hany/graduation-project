from core.time_utils import db_utc_now
from models import ContentCategory
from services.youtube_service import YouTubeServiceError, YouTubeVideo


def _create_category(db, *, slug: str = "english-youtube", axis_key: str = "educational"):
    category = ContentCategory(
        axis_key=axis_key,
        slug=slug,
        title_en="English",
        title_ar="English",
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def test_preview_youtube_channel_videos_returns_items(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
    monkeypatch,
):
    seed_builtin_rbac()
    admin = create_admin(email="yt.admin@example.com", role_names=["super_admin"])

    def _fake_list_channel_videos(*, channel_identifier, max_results=25, page_token=None):
        assert channel_identifier == "@SomeChannel"
        return (
            [
                YouTubeVideo(
                    video_id="abc123",
                    title="Counting Numbers",
                    description="Learn to count",
                    thumbnail_url="https://img.youtube.com/vi/abc123/hqdefault.jpg",
                    published_at="2026-01-01T00:00:00Z",
                )
            ],
            None,
        )

    monkeypatch.setattr(
        "routers.admin_cms.list_channel_videos",
        _fake_list_channel_videos,
    )

    response = client.get(
        "/admin/content/youtube/videos",
        headers=admin_headers(admin),
        params={"channel": "@SomeChannel"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["items"] == [
        {
            "video_id": "abc123",
            "title": "Counting Numbers",
            "description": "Learn to count",
            "thumbnail_url": "https://img.youtube.com/vi/abc123/hqdefault.jpg",
            "published_at": "2026-01-01T00:00:00Z",
            "url": "https://www.youtube.com/watch?v=abc123",
        }
    ]
    assert body["next_page_token"] is None


def test_preview_youtube_channel_videos_surfaces_service_errors(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
    monkeypatch,
):
    seed_builtin_rbac()
    admin = create_admin(email="yt.admin2@example.com", role_names=["super_admin"])

    def _raise(*_args, **_kwargs):
        raise YouTubeServiceError("YOUTUBE_API_KEY is not configured on the server.")

    monkeypatch.setattr("routers.admin_cms.list_channel_videos", _raise)

    response = client.get(
        "/admin/content/youtube/videos",
        headers=admin_headers(admin),
        params={"channel": "@SomeChannel"},
    )

    assert response.status_code == 502
    assert "YOUTUBE_API_KEY" in response.json()["detail"]


def test_import_youtube_videos_creates_content_items(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(email="yt.admin3@example.com", role_names=["super_admin"])
    category = _create_category(db)

    response = client.post(
        "/admin/content/youtube/import",
        headers=admin_headers(admin),
        json={
            "items": [
                {
                    "video_id": "abc123",
                    "category_id": category.id,
                    "title_en": "Counting Numbers",
                    "title_ar": "تعلم العد",
                    "description_en": "Learn to count",
                    "thumbnail_url": "https://img.youtube.com/vi/abc123/hqdefault.jpg",
                }
            ]
        },
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    created = items[0]
    assert created["video_url"] == "https://www.youtube.com/watch?v=abc123"
    assert created["video_provider"] == "youtube"
    assert created["category"]["id"] == category.id
    assert created["status"] == "draft"


def test_import_youtube_videos_requires_at_least_one_item(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(email="yt.admin4@example.com", role_names=["super_admin"])

    response = client.post(
        "/admin/content/youtube/import",
        headers=admin_headers(admin),
        json={"items": []},
    )

    assert response.status_code == 400

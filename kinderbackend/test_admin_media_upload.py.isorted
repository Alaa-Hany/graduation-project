from core.time_utils import db_utc_now
from models import ContentCategory, ContentItem
from services.media_service import UploadedVideoAsset


def _create_category(db, *, slug: str = "behavioral-media", axis_key: str = "behavioral"):
    category = ContentCategory(
        axis_key=axis_key,
        slug=slug,
        title_en="Behavioral Media",
        title_ar="Behavioral Media",
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def test_admin_video_upload_endpoint_returns_cloud_media_payload(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
    monkeypatch,
):
    seed_builtin_rbac()
    admin = create_admin(email="media.admin@example.com", role_names=["super_admin"])

    def _fake_upload_video(**_kwargs):
        return UploadedVideoAsset(
            video_url="https://cdn.example.com/video.mp4",
            thumbnail_url="https://cdn.example.com/video.jpg",
            provider="cloudinary",
            public_id="kinderworld/behavioral/video-123",
            duration_seconds=42,
            bytes_size=2048,
            format="mp4",
            resource_type="video",
            folder="kinderworld/behavioral",
        )

    monkeypatch.setattr(
        "routers.admin_cms.media_service.upload_video",
        _fake_upload_video,
    )

    response = client.post(
        "/admin/media/videos/upload",
        headers=admin_headers(admin),
        data={"axis_key": "behavioral", "content_slug": "kindness-video"},
        files={"file": ("kindness.mp4", b"fake-video-bytes", "video/mp4")},
    )

    assert response.status_code == 200
    item = response.json()["item"]
    assert item["video_url"] == "https://cdn.example.com/video.mp4"
    assert item["thumbnail_url"] == "https://cdn.example.com/video.jpg"
    assert item["video_provider"] == "cloudinary"
    assert item["video_public_id"] == "kinderworld/behavioral/video-123"
    assert item["video_duration_seconds"] == 42
    assert item["metadata_json"]["format"] == "mp4"


def test_published_video_content_requires_video_url(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(email="publish.video.admin@example.com", role_names=["super_admin"])
    category = _create_category(db)

    response = client.post(
        "/admin/contents",
        headers=admin_headers(admin),
        json={
            "category_id": category.id,
            "content_type": "video",
            "status": "published",
            "title_en": "Kindness Video",
            "title_ar": "Kindness Video",
            "body_en": "English body",
            "body_ar": "Arabic body",
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Published video content must include a video URL"


def test_public_child_content_item_exposes_video_fields(client, db):
    category = _create_category(db, slug="educational-video", axis_key="educational")
    content = ContentItem(
        category_id=category.id,
        slug="letters-song",
        content_type="video",
        status="published",
        title_en="Letters Song",
        title_ar="Letters Song",
        body_en="Sing the alphabet",
        body_ar="Sing the alphabet",
        thumbnail_url="https://cdn.example.com/thumb.jpg",
        video_url="https://cdn.example.com/letters.mp4",
        video_provider="cloudinary",
        video_public_id="kinderworld/educational/letters-song-123",
        video_duration_seconds=87,
        metadata_json={
            "video_preview_url": "https://cdn.example.com/letters-preview.mp4",
            "video_host_tier": "streaming",
        },
        published_at=db_utc_now(),
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(content)
    db.commit()

    response = client.get("/content/child/items/letters-song")
    assert response.status_code == 200
    item = response.json()["item"]
    assert item["video_url"] == "https://cdn.example.com/letters.mp4"
    assert item["video_provider"] == "cloudinary"
    assert item["video_public_id"] == "kinderworld/educational/letters-song-123"
    assert item["video_duration_seconds"] == 87
    assert item["metadata_json"]["video_preview_url"].endswith("letters-preview.mp4")

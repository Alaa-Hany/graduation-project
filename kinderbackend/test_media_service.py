"""Tests for services.media_service (Cloudinary signed video uploads).

All HTTP calls are mocked; tests exercise signing, folder/public-id building,
configuration gating, and response parsing/error handling.
"""

from types import SimpleNamespace

import pytest

import services.media_service as media_module
from services.media_service import (
    MediaService,
    MediaServiceError,
    UploadedVideoAsset,
)


def _configured_settings():
    return SimpleNamespace(
        cloudinary_cloud_name="demo-cloud",
        cloudinary_api_key="key-123",
        cloudinary_api_secret="secret-xyz",
        cloudinary_media_root_folder="kinder/media",
    )


@pytest.fixture
def configured(monkeypatch):
    monkeypatch.setattr(media_module, "settings", _configured_settings())
    return MediaService()


# ---------------------------------------------------------------------------
# is_configured
# ---------------------------------------------------------------------------


def test_is_configured_true_when_all_present(configured):
    assert configured.is_configured is True


def test_is_configured_false_when_missing(monkeypatch):
    settings = _configured_settings()
    settings.cloudinary_api_secret = None
    monkeypatch.setattr(media_module, "settings", settings)
    assert MediaService().is_configured is False


# ---------------------------------------------------------------------------
# helper methods
# ---------------------------------------------------------------------------


def test_slugify_normalizes_and_collapses(configured):
    assert configured._slugify("  Hello   World!! ") == "hello-world"
    assert configured._slugify("a__b") == "a-b"
    assert configured._slugify("***") == ""


def test_build_folder_includes_axis_and_category(configured):
    folder = configured._build_folder(axis_key="Cognitive Axis", category_slug="Math 101")
    assert folder == "kinder/media/cognitive-axis/math-101"


def test_build_folder_skips_blank_parts(configured):
    assert configured._build_folder(axis_key=None, category_slug=None) == "kinder/media"


def test_build_public_id_uses_content_slug(configured):
    public_id = configured._build_public_id(filename="ignored.mp4", content_slug="My Lesson")
    assert public_id.startswith("my-lesson-")


def test_build_public_id_falls_back_to_filename_stem(configured):
    public_id = configured._build_public_id(filename="Counting Game.mp4", content_slug=None)
    assert public_id.startswith("counting-game-")


def test_sign_is_deterministic_sorted_sha1(configured):
    params = {"timestamp": "100", "folder": "a", "public_id": "b"}
    # sha1("folder=a&public_id=b&timestamp=100" + "secret-xyz")
    import hashlib

    expected = hashlib.sha1(b"folder=a&public_id=b&timestamp=100secret-xyz").hexdigest()
    assert configured._sign(params) == expected


def test_thumbnail_url_with_and_without_version(configured):
    with_version = configured._thumbnail_url("vid123", version=7)
    assert "/v7/so_0/vid123.jpg" in with_version
    without_version = configured._thumbnail_url("vid123", version=None)
    assert without_version.endswith("/upload/so_0/vid123.jpg")


def test_upload_url_includes_cloud_name(configured):
    assert configured._upload_url() == (
        "https://api.cloudinary.com/v1_1/demo-cloud/video/upload"
    )


# ---------------------------------------------------------------------------
# to_payload
# ---------------------------------------------------------------------------


def test_uploaded_asset_to_payload_full():
    asset = UploadedVideoAsset(
        video_url="https://cdn/v.mp4",
        thumbnail_url="https://cdn/v.jpg",
        provider="cloudinary",
        public_id="pid",
        duration_seconds=42,
        bytes_size=1000,
        format="mp4",
        resource_type="video",
        folder="kinder/media",
    )
    payload = asset.to_payload()
    assert payload["video_url"] == "https://cdn/v.mp4"
    assert payload["video_duration_seconds"] == 42
    assert payload["metadata_json"]["format"] == "mp4"
    assert payload["metadata_json"]["bytes"] == 1000
    assert payload["metadata_json"]["duration_seconds"] == 42


def test_uploaded_asset_to_payload_omits_optional_metadata():
    asset = UploadedVideoAsset(
        video_url="https://cdn/v.mp4",
        thumbnail_url=None,
        provider="cloudinary",
        public_id="pid",
        duration_seconds=None,
        bytes_size=None,
        format=None,
        resource_type="video",
        folder="kinder/media",
    )
    metadata = asset.to_payload()["metadata_json"]
    assert "format" not in metadata
    assert "bytes" not in metadata
    assert "duration_seconds" not in metadata


# ---------------------------------------------------------------------------
# upload_video
# ---------------------------------------------------------------------------


def test_upload_video_unconfigured_raises(monkeypatch):
    settings = _configured_settings()
    settings.cloudinary_cloud_name = None
    monkeypatch.setattr(media_module, "settings", settings)
    with pytest.raises(MediaServiceError, match="not configured"):
        MediaService().upload_video(file_bytes=b"x", filename="a.mp4")


def test_upload_video_empty_bytes_raises(configured):
    with pytest.raises(MediaServiceError, match="empty"):
        configured.upload_video(file_bytes=b"", filename="a.mp4")


def test_upload_video_success(configured, monkeypatch):
    captured = {}

    def fake_post(url, data, files, timeout):
        captured["url"] = url
        captured["data"] = data
        captured["files"] = files
        return SimpleNamespace(
            status_code=200,
            json=lambda: {
                "secure_url": "https://cdn/result.mp4",
                "public_id": "kinder/media/clip-1",
                "duration": 12.7,
                "bytes": 2048,
                "version": 99,
                "format": "mp4",
                "resource_type": "video",
            },
        )

    monkeypatch.setattr(media_module.httpx, "post", fake_post)

    asset = configured.upload_video(
        file_bytes=b"video-bytes",
        filename="clip.mp4",
        axis_key="axis",
        category_slug="cat",
        content_slug="clip",
        mime_type="video/mp4",
    )

    assert asset.video_url == "https://cdn/result.mp4"
    assert asset.public_id == "kinder/media/clip-1"
    assert asset.duration_seconds == 12  # truncated via int()
    assert asset.bytes_size == 2048
    assert asset.format == "mp4"
    assert "v99/so_0/kinder/media/clip-1.jpg" in asset.thumbnail_url
    # The signed request carried the api key + signature.
    assert captured["data"]["api_key"] == "key-123"
    assert "signature" in captured["data"]


def test_upload_video_http_error_raises(configured, monkeypatch):
    monkeypatch.setattr(
        media_module.httpx,
        "post",
        lambda *a, **k: SimpleNamespace(status_code=500, json=lambda: {}),
    )
    with pytest.raises(MediaServiceError, match="status 500"):
        configured.upload_video(file_bytes=b"x", filename="a.mp4")


def test_upload_video_missing_url_in_response_raises(configured, monkeypatch):
    monkeypatch.setattr(
        media_module.httpx,
        "post",
        lambda *a, **k: SimpleNamespace(
            status_code=200, json=lambda: {"secure_url": "", "public_id": ""}
        ),
    )
    with pytest.raises(MediaServiceError, match="usable video URL"):
        configured.upload_video(file_bytes=b"x", filename="a.mp4")

from __future__ import annotations

import hashlib
import time
from dataclasses import dataclass

import httpx

from core.settings import settings


class MediaServiceError(RuntimeError):
    pass


@dataclass(frozen=True)
class UploadedVideoAsset:
    video_url: str
    thumbnail_url: str | None
    provider: str
    public_id: str
    duration_seconds: int | None
    bytes_size: int | None
    format: str | None
    resource_type: str
    folder: str

    def to_payload(self) -> dict[str, object | None]:
        metadata_json = {
            "resource_type": self.resource_type,
            "folder": self.folder,
        }
        if self.format:
            metadata_json["format"] = self.format
        if self.bytes_size is not None:
            metadata_json["bytes"] = self.bytes_size
        if self.duration_seconds is not None:
            metadata_json["duration_seconds"] = self.duration_seconds
        return {
            "video_url": self.video_url,
            "thumbnail_url": self.thumbnail_url,
            "video_provider": self.provider,
            "video_public_id": self.public_id,
            "video_duration_seconds": self.duration_seconds,
            "metadata_json": metadata_json,
        }


class MediaService:
    provider_name = "cloudinary"

    @property
    def is_configured(self) -> bool:
        return bool(
            settings.cloudinary_cloud_name
            and settings.cloudinary_api_key
            and settings.cloudinary_api_secret
        )

    def upload_video(
        self,
        *,
        file_bytes: bytes,
        filename: str,
        axis_key: str | None = None,
        category_slug: str | None = None,
        content_slug: str | None = None,
        mime_type: str | None = None,
    ) -> UploadedVideoAsset:
        if not self.is_configured:
            raise MediaServiceError("Cloudinary media uploads are not configured")
        if not file_bytes:
            raise MediaServiceError("Uploaded video file is empty")

        timestamp = int(time.time())
        folder = self._build_folder(axis_key=axis_key, category_slug=category_slug)
        public_id = self._build_public_id(filename=filename, content_slug=content_slug)
        params_to_sign = {
            "folder": folder,
            "public_id": public_id,
            "timestamp": str(timestamp),
        }
        signature = self._sign(params_to_sign)
        response = httpx.post(
            self._upload_url(),
            data={
                **params_to_sign,
                "api_key": settings.cloudinary_api_key,
                "signature": signature,
            },
            files={
                "file": (
                    filename,
                    file_bytes,
                    mime_type or "application/octet-stream",
                )
            },
            timeout=900.0,
        )

        if response.status_code >= 400:
            raise MediaServiceError(f"Cloudinary upload failed with status {response.status_code}")

        payload = response.json()
        secure_url = str(payload.get("secure_url") or "").strip()
        public_id_value = str(payload.get("public_id") or "").strip()
        if not secure_url or not public_id_value:
            raise MediaServiceError("Cloudinary response did not include a usable video URL")

        duration_raw = payload.get("duration")
        duration_seconds = int(duration_raw) if duration_raw is not None else None
        bytes_raw = payload.get("bytes")
        bytes_size = int(bytes_raw) if bytes_raw is not None else None
        version = payload.get("version")
        return UploadedVideoAsset(
            video_url=secure_url,
            thumbnail_url=self._thumbnail_url(public_id_value, version=version),
            provider=self.provider_name,
            public_id=public_id_value,
            duration_seconds=duration_seconds,
            bytes_size=bytes_size,
            format=(payload.get("format") or None),
            resource_type=str(payload.get("resource_type") or "video"),
            folder=folder,
        )

    def _upload_url(self) -> str:
        return f"https://api.cloudinary.com/v1_1/" f"{settings.cloudinary_cloud_name}/video/upload"

    def _build_folder(self, *, axis_key: str | None, category_slug: str | None) -> str:
        parts = [settings.cloudinary_media_root_folder]
        if axis_key:
            parts.append(self._slugify(axis_key))
        if category_slug:
            parts.append(self._slugify(category_slug))
        return "/".join(part for part in parts if part)

    def _build_public_id(self, *, filename: str, content_slug: str | None) -> str:
        stem = content_slug or filename.rsplit(".", 1)[0]
        normalized = self._slugify(stem) or "video"
        return f"{normalized}-{int(time.time() * 1000)}"

    def _thumbnail_url(self, public_id: str, *, version: object | None) -> str:
        version_segment = f"v{version}/" if version else ""
        return (
            f"https://res.cloudinary.com/{settings.cloudinary_cloud_name}/video/upload/"
            f"{version_segment}so_0/{public_id}.jpg"
        )

    def _sign(self, params: dict[str, str]) -> str:
        serialized = "&".join(f"{key}={params[key]}" for key in sorted(params))
        raw = f"{serialized}{settings.cloudinary_api_secret}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    def _slugify(self, value: str) -> str:
        normalized = "".join(char.lower() if char.isalnum() else "-" for char in value.strip())
        while "--" in normalized:
            normalized = normalized.replace("--", "-")
        return normalized.strip("-")


media_service = MediaService()

from __future__ import annotations

import base64
import io
import re
import warnings

from PIL import Image

_ALLOWED_AVATAR_ID_RE = re.compile(r"^(?:avatar_\d+|boy\d+|girl\d+|av\d+)$")
_ALLOWED_AVATAR_PATH_RE = re.compile(
    r"^assets/(?:images/avatars|avatars/kids)/[A-Za-z0-9._/-]+\.(?:png|jpg|jpeg|webp)$"
)
_DATA_URL_RE = re.compile(
    r"^data:(?P<mime>image/(?:png|jpeg|webp));base64,(?P<data>.+)$",
    re.IGNORECASE,
)
_FORMAT_BY_MIME = {
    "image/png": "PNG",
    "image/jpeg": "JPEG",
    "image/webp": "WEBP",
}
_MAX_IMAGE_BYTES = 2 * 1024 * 1024
_MAX_IMAGE_WIDTH = 4096
_MAX_IMAGE_HEIGHT = 4096
_MAX_IMAGE_PIXELS = 8_000_000


def _validate_inline_avatar_image(value: str) -> str:
    match = _DATA_URL_RE.fullmatch(value)
    if match is None:
        raise ValueError("avatar image must be a valid base64 data URL")

    mime = match.group("mime").lower()
    encoded = "".join(match.group("data").split())
    try:
        image_bytes = base64.b64decode(encoded, validate=True)
    except (ValueError, base64.binascii.Error) as exc:
        raise ValueError("avatar image data is not valid base64") from exc

    if not image_bytes:
        raise ValueError("avatar image data is empty")
    if len(image_bytes) > _MAX_IMAGE_BYTES:
        raise ValueError("avatar image exceeds the 2 MB size limit")

    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(image_bytes)) as image:
                width, height = image.size
                image_format = (image.format or "").upper()
                image.verify()
    except (Image.UnidentifiedImageError, OSError, Image.DecompressionBombWarning) as exc:
        raise ValueError("avatar image is malformed or unsupported") from exc

    expected_format = _FORMAT_BY_MIME[mime]
    if image_format != expected_format:
        raise ValueError("avatar image type does not match the file content")
    if width < 1 or height < 1:
        raise ValueError("avatar image dimensions are invalid")
    if width > _MAX_IMAGE_WIDTH or height > _MAX_IMAGE_HEIGHT:
        raise ValueError("avatar image dimensions exceed the supported limit")
    if width * height > _MAX_IMAGE_PIXELS:
        raise ValueError("avatar image resolution exceeds the supported limit")

    return f"data:{mime};base64,{encoded}"


def normalize_child_avatar(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip()
    if not normalized:
        return None

    lowered = normalized.lower()
    if _ALLOWED_AVATAR_ID_RE.fullmatch(lowered):
        return lowered
    if _ALLOWED_AVATAR_PATH_RE.fullmatch(normalized):
        return normalized
    if lowered.startswith("data:image/"):
        return _validate_inline_avatar_image(normalized)

    raise ValueError(
        "avatar must be a supported avatar id, local avatar asset path, or PNG/JPEG/WEBP data URL"
    )

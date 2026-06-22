from __future__ import annotations

from dataclasses import dataclass

import httpx

from core.settings import settings

YOUTUBE_API_BASE_URL = "https://www.googleapis.com/youtube/v3"


class YouTubeServiceError(RuntimeError):
    pass


@dataclass(frozen=True)
class YouTubeVideo:
    video_id: str
    title: str
    description: str
    thumbnail_url: str | None
    published_at: str | None

    @property
    def url(self) -> str:
        return f"https://www.youtube.com/watch?v={self.video_id}"

    def to_payload(self) -> dict[str, object | None]:
        return {
            "video_id": self.video_id,
            "title": self.title,
            "description": self.description,
            "thumbnail_url": self.thumbnail_url,
            "published_at": self.published_at,
            "url": self.url,
        }


def _require_api_key() -> str:
    if not settings.youtube_api_key:
        raise YouTubeServiceError(
            "YOUTUBE_API_KEY is not configured on the server."
        )
    return settings.youtube_api_key


def _get(client: httpx.Client, path: str, params: dict[str, str]) -> dict:
    response = client.get(
        f"{YOUTUBE_API_BASE_URL}/{path}",
        params={**params, "key": _require_api_key()},
        timeout=10.0,
    )
    if response.status_code != 200:
        detail = response.text
        raise YouTubeServiceError(f"YouTube API request failed: {detail}")
    return response.json()


def resolve_channel_id(client: httpx.Client, identifier: str) -> str:
    """Resolve a channel ID, @handle, or channel URL to a channel ID."""
    value = identifier.strip()
    if not value:
        raise YouTubeServiceError("A channel ID, handle, or URL is required.")

    if value.startswith("http://") or value.startswith("https://"):
        path = value.split("youtube.com/", 1)[-1].strip("/")
        value = path.split("/")[-1] if path else value

    if value.startswith("UC") and len(value) == 24:
        return value

    handle = value[1:] if value.startswith("@") else value
    data = _get(client, "channels", {"part": "id", "forHandle": handle})
    items = data.get("items") or []
    if not items:
        raise YouTubeServiceError(f"No YouTube channel found for '{identifier}'.")
    return items[0]["id"]


def get_uploads_playlist_id(client: httpx.Client, channel_id: str) -> str:
    data = _get(
        client,
        "channels",
        {"part": "contentDetails", "id": channel_id},
    )
    items = data.get("items") or []
    if not items:
        raise YouTubeServiceError(f"Channel '{channel_id}' was not found.")
    return items[0]["contentDetails"]["relatedPlaylists"]["uploads"]


def list_channel_videos(
    *,
    channel_identifier: str,
    max_results: int = 25,
    page_token: str | None = None,
) -> tuple[list[YouTubeVideo], str | None]:
    max_results = max(1, min(max_results, 50))
    with httpx.Client() as client:
        channel_id = resolve_channel_id(client, channel_identifier)
        uploads_playlist_id = get_uploads_playlist_id(client, channel_id)
        params = {
            "part": "snippet",
            "playlistId": uploads_playlist_id,
            "maxResults": str(max_results),
        }
        if page_token:
            params["pageToken"] = page_token
        data = _get(client, "playlistItems", params)

    videos = [
        YouTubeVideo(
            video_id=item["snippet"]["resourceId"]["videoId"],
            title=item["snippet"].get("title", ""),
            description=item["snippet"].get("description", ""),
            thumbnail_url=(item["snippet"].get("thumbnails") or {})
            .get("high", {})
            .get("url"),
            published_at=item["snippet"].get("publishedAt"),
        )
        for item in data.get("items") or []
    ]
    next_page_token = data.get("nextPageToken")
    return videos, next_page_token

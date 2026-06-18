from __future__ import annotations

from fastapi import Request
from starlette.responses import Response

_API_CONTENT_SECURITY_POLICY = (
    "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
)
_PERMISSIONS_POLICY = (
    "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
    "magnetometer=(), microphone=(), payment=(), usb=()"
)
_HSTS_VALUE = "max-age=63072000; includeSubDomains"
_HTML_DOC_PATH_PREFIXES = ("/docs", "/redoc")


def _is_https_request(request: Request) -> bool:
    forwarded_proto = (request.headers.get("X-Forwarded-Proto") or "").split(",", 1)[0].strip()
    if forwarded_proto:
        return forwarded_proto.lower() == "https"
    return request.url.scheme.lower() == "https"


def _should_add_csp(request: Request, response: Response) -> bool:
    if any(request.url.path.startswith(prefix) for prefix in _HTML_DOC_PATH_PREFIXES):
        return False
    content_type = (response.headers.get("content-type") or "").lower()
    return not content_type.startswith("text/html")


def apply_security_headers(
    request: Request,
    response: Response,
    *,
    is_production: bool,
) -> None:
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault("Permissions-Policy", _PERMISSIONS_POLICY)

    if _should_add_csp(request, response):
        response.headers.setdefault("Content-Security-Policy", _API_CONTENT_SECURITY_POLICY)

    if is_production and _is_https_request(request):
        response.headers.setdefault("Strict-Transport-Security", _HSTS_VALUE)

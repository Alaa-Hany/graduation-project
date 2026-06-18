import logging
import time
from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# Import admin_models so SQLAlchemy registers the tables with Base.metadata
import admin_models  # noqa: F401
from core.envelope_middleware import EnvelopeMiddleware
from core.exception_handlers import build_error_body, register_exception_handlers
from core.logging_utils import configure_logging, log_with_context
from core.message_catalog import MaintenanceMessages
from core.request_id_middleware import RequestIdMiddleware
from core.security_headers import apply_security_headers
from core.settings import settings
from core.system_settings import is_maintenance_mode
from database import SessionLocal, engine
from db_migrations import verify_database_schema
from routers.admin_admins import router as admin_admins_router
from routers.admin_analytics import router as admin_analytics_router
from routers.admin_audit import router as admin_audit_router
from routers.admin_auth import router as admin_auth_router
from routers.admin_children import router as admin_children_router
from routers.admin_cms import router as admin_cms_router
from routers.admin_diagnostics import router as admin_diagnostics_router
from routers.admin_seed import SEED_ENABLED as ADMIN_SEED_ENABLED
from routers.admin_seed import router as admin_seed_router
from routers.admin_settings import router as admin_settings_router
from routers.admin_subscriptions import router as admin_subscriptions_router
from routers.admin_support import router as admin_support_router
from routers.admin_users import router as admin_users_router
from routers.ai_buddy import router as ai_buddy_router
from routers.auth import router as auth_router
from routers.billing_methods import router as billing_methods_router
from routers.children import router as children_router
from routers.content import router as content_router
from routers.features import router as features_router
from routers.health import router as health_router
from routers.notifications import router as notifications_router
from routers.parental_controls import router as parental_controls_router
from routers.payment_webhooks import router as payment_webhooks_router
from routers.privacy import router as privacy_router
from routers.public_auth import router as public_auth_router
from routers.subscription import billing_router as subscription_billing_router
from routers.subscription import public_router as subscription_public_router
from routers.subscription import router as subscription_router
from routers.support import router as support_router
from routers.voice import router as voice_router

configure_logging(settings)

if settings.sentry_dsn:
    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.environment,
        traces_sample_rate=0.2,
        send_default_pii=False,
    )

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# API versioning
# ---------------------------------------------------------------------------
API_V1_PREFIX = "/api/v1"  # legacy-compatible; no envelope
API_V2_PREFIX = "/api/v2"  # envelope-wrapped responses

# Keep the single constant used elsewhere (e.g. maintenance bypass).
API_VERSION = "v1"
API_PREFIX = API_V1_PREFIX

_DEV_CORS_ORIGIN_REGEX = (
    r"^https?://("
    r"localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|"
    r"10(?:\.\d{1,3}){3}|"
    r"192\.168(?:\.\d{1,3}){2}|"
    r"172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2}"
    r")(?::\d+)?$"
)

_MAINTENANCE_BYPASS_PREFIXES = (
    f"{API_V1_PREFIX}/admin",  # /api/v1/admin
    f"{API_V2_PREFIX}/admin",  # /api/v2/admin
    "/docs",
    "/redoc",
    "/openapi.json",
    "/webhooks",  # payment webhooks are intentionally unversioned
    "/health",  # health checks are intentionally unversioned
)
_MAINTENANCE_BYPASS_PATHS = {
    "/",
}

# ---------------------------------------------------------------------------
# Process-level maintenance-mode cache (5-second TTL)
# ---------------------------------------------------------------------------
_MAINTENANCE_CACHE_TTL = 5.0  # seconds
_maintenance_cache: bool | None = None
_maintenance_cache_expires_at: float = 0.0


def _run_startup_checks() -> None:
    if settings.skip_schema_verify:
        log_with_context(
            logger,
            logging.WARNING,
            "schema_verification_skipped",
            event="schema_verification_skipped",
            category="app",
            environment=getattr(settings, "environment", None),
            outcome="skipped",
        )
        return
    verify_database_schema(
        engine,
        logger,
        auto_upgrade=settings.auto_run_migrations,
    )


def _cors_config() -> dict[str, object]:
    allowed_origins = list(settings.allowed_origins)
    allowed_origin_regex = settings.allowed_origin_regex

    if not settings.is_production and not allowed_origins and not allowed_origin_regex:
        allowed_origin_regex = _DEV_CORS_ORIGIN_REGEX

    if settings.is_production and not allowed_origins and not allowed_origin_regex:
        log_with_context(
            logger,
            logging.WARNING,
            "cors_effectively_disabled",
            event="cors_effectively_disabled",
            category="app",
            environment=getattr(settings, "environment", None),
            outcome="warning",
        )

    log_with_context(
        logger,
        logging.INFO,
        "cors_configured",
        event="cors_configured",
        category="app",
        environment=getattr(settings, "environment", None),
        allowed_origins_count=len(allowed_origins),
        has_origin_regex=bool(allowed_origin_regex),
        allow_credentials=settings.cors_allow_credentials,
    )

    return {
        "allow_origins": allowed_origins,
        "allow_origin_regex": allowed_origin_regex,
        "allow_credentials": settings.cors_allow_credentials,
    }


@asynccontextmanager
async def lifespan(_: FastAPI):
    log_with_context(
        logger,
        logging.INFO,
        "application_startup_initialized",
        event="application_startup_initialized",
        category="app",
        environment=getattr(settings, "environment", None),
    )
    _run_startup_checks()
    try:
        yield
    finally:
        log_with_context(
            logger,
            logging.INFO,
            "application_shutdown_complete",
            event="application_shutdown_complete",
            category="app",
            environment=getattr(settings, "environment", None),
        )


app = FastAPI(lifespan=lifespan)
register_exception_handlers(app)
# Middleware execution order is LIFO: RequestIdMiddleware runs first (sets
# request_id in context), then EnvelopeMiddleware reads that id when wrapping.
app.add_middleware(EnvelopeMiddleware)
app.add_middleware(RequestIdMiddleware)

cors_config = _cors_config()

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_config["allow_origins"],
    allow_origin_regex=cors_config["allow_origin_regex"],
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Accept",
        "X-Requested-With",
        "X-CSRF-Token",
        "X-Request-ID",
    ],
    expose_headers=["X-Request-ID"],
    allow_credentials=bool(cors_config["allow_credentials"]),
    max_age=86400,
)


@app.middleware("http")
async def security_headers_middleware(request, call_next):
    response = await call_next(request)
    apply_security_headers(request, response, is_production=settings.is_production)
    return response


def _get_maintenance_mode_cached() -> bool:
    """Return the maintenance-mode flag, refreshing from the DB at most once every
    ``_MAINTENANCE_CACHE_TTL`` seconds to avoid a DB round-trip on every request."""
    global _maintenance_cache, _maintenance_cache_expires_at

    now = time.monotonic()
    if _maintenance_cache is None or now >= _maintenance_cache_expires_at:
        db = SessionLocal()
        try:
            _maintenance_cache = is_maintenance_mode(db)
        finally:
            db.close()
        _maintenance_cache_expires_at = now + _MAINTENANCE_CACHE_TTL

    return _maintenance_cache


@app.middleware("http")
async def maintenance_mode_guard(request, call_next):
    path = request.url.path
    if request.method == "OPTIONS":
        return await call_next(request)
    if path in _MAINTENANCE_BYPASS_PATHS or any(
        path.startswith(prefix) for prefix in _MAINTENANCE_BYPASS_PREFIXES
    ):
        return await call_next(request)

    if _get_maintenance_mode_cached():
        return JSONResponse(
            status_code=503,
            content=build_error_body(
                status_code=503,
                detail={
                    "message": MaintenanceMessages.SERVICE_TEMPORARILY_UNAVAILABLE,
                    "code": "APP_MAINTENANCE_MODE",
                },
            ),
        )

    return await call_next(request)


@app.get("/")
def root():
    return {
        "service_name": "kinderbackend",
        "version": API_VERSION,
        "environment": getattr(settings, "environment", "unknown"),
        "status": "running",
    }


def _include_api_router(router) -> None:
    """Register a router at three prefixes:

    * bare (legacy, no prefix)           → raw response, no envelope
    * /api/v1 (versioned legacy)         → raw response, no envelope
    * /api/v2 (new standard)             → response wrapped in envelope

    Business logic lives entirely in the service layer and is reused across
    all three registrations — no duplication.
    """
    app.include_router(router)  # bare / legacy
    app.include_router(router, prefix=API_V1_PREFIX)  # /api/v1 — no envelope
    app.include_router(router, prefix=API_V2_PREFIX)  # /api/v2 — envelope applied


# --- App routes, available as legacy, /api/v1, and /api/v2 paths ------------
_include_api_router(children_router)
_include_api_router(public_auth_router)
_include_api_router(subscription_router)
_include_api_router(subscription_public_router)
_include_api_router(subscription_billing_router)
_include_api_router(billing_methods_router)
_include_api_router(auth_router)
_include_api_router(notifications_router)
_include_api_router(privacy_router)
_include_api_router(content_router)
_include_api_router(support_router)
_include_api_router(features_router)
_include_api_router(parental_controls_router)
_include_api_router(ai_buddy_router)
_include_api_router(voice_router)

# --- Admin routes, available as legacy, /api/v1, and /api/v2 paths ----------
_include_api_router(admin_auth_router)
_include_api_router(admin_admins_router)
_include_api_router(admin_users_router)
_include_api_router(admin_children_router)
_include_api_router(admin_audit_router)
_include_api_router(admin_support_router)
_include_api_router(admin_analytics_router)
_include_api_router(admin_cms_router)
_include_api_router(admin_subscriptions_router)
_include_api_router(admin_settings_router)
_include_api_router(admin_diagnostics_router)
if ADMIN_SEED_ENABLED:
    log_with_context(
        logger,
        logging.WARNING,
        "admin_seed_endpoint_enabled",
        event="admin_seed_endpoint_enabled",
        category="app",
        environment=getattr(settings, "environment", None),
        outcome="warning",
    )
    _include_api_router(admin_seed_router)

# --- Unversioned infrastructure routes ------------------------------------
# health_router stays at /health — probed by load balancers without a version.
# payment_webhooks_

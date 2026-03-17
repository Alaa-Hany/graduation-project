import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# Import admin_models so SQLAlchemy registers the tables with Base.metadata
import admin_models  # noqa: F401
from core.exception_handlers import register_exception_handlers
from core.logging_utils import configure_logging
from core.request_id_middleware import RequestIdMiddleware
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
from routers.admin_diagnostics import router as admin_diagnostics_router

configure_logging(settings)

logger = logging.getLogger(__name__)

_DEV_CORS_ORIGIN_REGEX = (
    r"^https?://("
    r"localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|"
    r"10(?:\.\d{1,3}){3}|"
    r"192\.168(?:\.\d{1,3}){2}|"
    r"172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2}"
    r")(?::\d+)?$"
)

_MAINTENANCE_BYPASS_PREFIXES = (
    "/admin",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/webhooks",
)
_MAINTENANCE_BYPASS_PATHS = {
    "/",
}


def _run_startup_checks() -> None:
    if settings.skip_schema_verify:
        logger.warning("Skipping database schema verification (SKIP_SCHEMA_VERIFY enabled)")
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
        logger.warning(
            "CORS is effectively disabled in production because no ALLOWED_ORIGINS "
            "or ALLOWED_ORIGIN_REGEX values were configured."
        )

    logger.info(
        "CORS configured",
        extra={
            "allowed_origins_count": len(allowed_origins),
            "has_origin_regex": bool(allowed_origin_regex),
            "allow_credentials": settings.cors_allow_credentials,
            "environment": settings.environment,
        },
    )

    return {
        "allow_origins": allowed_origins,
        "allow_origin_regex": allowed_origin_regex,
        "allow_credentials": settings.cors_allow_credentials,
    }


@asynccontextmanager
async def lifespan(_: FastAPI):
    logger.info("Application startup initialized")
    _run_startup_checks()
    try:
        yield
    finally:
        logger.info("Application shutdown complete")


app = FastAPI(lifespan=lifespan)
register_exception_handlers(app)
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
async def maintenance_mode_guard(request, call_next):
    path = request.url.path
    if request.method == "OPTIONS":
        return await call_next(request)
    if path in _MAINTENANCE_BYPASS_PATHS or any(
        path.startswith(prefix) for prefix in _MAINTENANCE_BYPASS_PREFIXES
    ):
        return await call_next(request)

    db = SessionLocal()
    try:
        if is_maintenance_mode(db):
            return JSONResponse(
                status_code=503,
                content={
                    "detail": {
                        "message": "Service temporarily unavailable: maintenance mode",
                        "code": "APP_MAINTENANCE_MODE",
                    }
                },
            )
    finally:
        db.close()

    return await call_next(request)


@app.get("/")
def root():
    return {"message": "Backend is running"}


app.include_router(children_router)
app.include_router(public_auth_router)
app.include_router(subscription_router)
app.include_router(subscription_public_router)
app.include_router(subscription_billing_router)
app.include_router(billing_methods_router)
app.include_router(auth_router)
app.include_router(notifications_router)
app.include_router(privacy_router)
app.include_router(content_router)
app.include_router(support_router)
app.include_router(features_router)
app.include_router(parental_controls_router)
app.include_router(ai_buddy_router)
app.include_router(payment_webhooks_router)
app.include_router(health_router)

app.include_router(admin_auth_router)
app.include_router(admin_admins_router)
app.include_router(admin_users_router)
app.include_router(admin_children_router)
app.include_router(admin_audit_router)
app.include_router(admin_support_router)
app.include_router(admin_analytics_router)
app.include_router(admin_cms_router)
app.include_router(admin_subscriptions_router)
app.include_router(admin_settings_router)
app.include_router(admin_diagnostics_router)
if ADMIN_SEED_ENABLED:
    logger.warning("Admin seed endpoint is enabled for this environment")
    app.include_router(admin_seed_router)

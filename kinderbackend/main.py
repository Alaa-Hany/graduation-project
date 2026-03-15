import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.exception_handlers import register_exception_handlers
from core.logging_utils import configure_logging
from core.request_id_middleware import RequestIdMiddleware
from core.settings import settings
from core.system_settings import is_maintenance_mode
from database import engine
from database import SessionLocal
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
from routers.auth import router as auth_router
from routers.billing_methods import router as billing_methods_router
from routers.children import router as children_router
from routers.content import router as content_router
from routers.features import router as features_router
from routers.notifications import router as notifications_router
from routers.parental_controls import router as parental_controls_router
from routers.privacy import router as privacy_router
from routers.public_auth import router as public_auth_router
from routers.subscription import (
    billing_router as subscription_billing_router,
)
from routers.subscription import public_router as subscription_public_router
from routers.subscription import router as subscription_router
from routers.support import router as support_router

# Import admin_models so SQLAlchemy registers the tables with Base.metadata
import admin_models  # noqa: F401

configure_logging(settings)

logger = logging.getLogger(__name__)

app = FastAPI()
register_exception_handlers(app)
app.add_middleware(RequestIdMiddleware)

dev_mode = not settings.is_production

app.add_middleware(
    CORSMiddleware,
    # Dev: allow Flutter web on any localhost/LAN port without CORS preflight failures.
    allow_origins=["*"] if dev_mode else [],
    allow_origin_regex=None,
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
    allow_credentials=True,
    max_age=86400,
)

_MAINTENANCE_BYPASS_PREFIXES = (
    "/admin",
    "/docs",
    "/redoc",
    "/openapi.json",
)
_MAINTENANCE_BYPASS_PATHS = {
    "/",
}


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


@app.on_event("startup")
def on_startup():
    if settings.skip_schema_verify:
        logger.warning("Skipping database schema verification (SKIP_SCHEMA_VERIFY enabled)")
        return
    verify_database_schema(engine, logger, auto_upgrade=settings.auto_run_migrations)


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
if ADMIN_SEED_ENABLED:
    logger.warning("Admin seed endpoint is enabled for this environment")
    app.include_router(admin_seed_router)

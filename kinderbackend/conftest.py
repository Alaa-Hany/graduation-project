import os

import pytest
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

from test_client_compat import TestClient

# Ensure tests have deterministic auth/admin env defaults before app imports.
os.environ.setdefault("SECRET_KEY", "TEST_ONLY_PLACEHOLDER_SECRET")
os.environ.setdefault("KINDER_JWT_SECRET", os.environ["SECRET_KEY"])
os.environ.setdefault("ENABLE_ADMIN_SEED_ENDPOINT", "true")
os.environ.setdefault("ADMIN_SEED_SECRET", "TEST_ONLY_PLACEHOLDER_SECRET")
os.environ.setdefault("ADMIN_SEED_PASSWORD", "CHANGE_ME")
os.environ.setdefault("ADMIN_SEED_EMAIL", "change-me@example.invalid")
os.environ.setdefault("ADMIN_SEED_NAME", "DEV ONLY ADMIN")
os.environ.setdefault("SKIP_SCHEMA_VERIFY", "true")
os.environ.setdefault("DATA_ENCRYPTION_KEY", "TEST_ONLY_PLACEHOLDER_ENCRYPTION_KEY")
os.environ.setdefault("AI_PROVIDER_MODE", "fallback")


@pytest.fixture(scope="session")
def test_db():
    import admin_models  # noqa: F401
    import models  # noqa: F401
    from database import Base

    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    return engine


@pytest.fixture
def db(test_db):
    from database import Base, SessionLocal

    session = SessionLocal(bind=test_db)
    yield session
    session.close()
    # Truncate every table after each test so application-level commits
    # (which bypass the old rollback-based isolation under SQLAlchemy 2.0)
    # don't leak data into the next test.
    with test_db.begin() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            conn.execute(table.delete())


@pytest.fixture
def client(db):
    import main as main_module
    from deps import get_db
    from main import app

    def override_get_db():
        return db

    original_is_maintenance_mode = main_module.is_maintenance_mode
    main_module.is_maintenance_mode = lambda _db: False
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    main_module.is_maintenance_mode = original_is_maintenance_mode


@pytest.fixture(autouse=True)
def reset_global_state():
    # Clear in-process rate-limit fallback between tests (used when REDIS_URL is unset).
    # Auth/child service login-attempt state is Redis-backed; with no Redis in tests
    # those counters are no-ops, so there is nothing to clear here.
    from rate_limit import _fallback

    # Clear RBAC permission cache between tests.  SQLite recycles row IDs when a
    # transaction is rolled back (the table becomes empty so MAX(id)+1 = 1 again).
    # Without this, a "no-role admin" test caches (id=1, token_version=0) → frozenset(),
    # and the next test that creates a real admin also gets id=1 — hitting the stale
    # cache entry and receiving 403 despite having valid roles seeded.
    from admin_deps import _perm_cache
    from services.auth_service import _FAILED_LOGIN_ATTEMPTS, _LOGIN_LOCKOUTS
    from services.child_service import _DEVICE_BINDINGS, _FAILED_ATTEMPTS
    from test_redis_mock import reset_mock_redis

    _fallback.requests.clear()
    _perm_cache._store.clear()
    _FAILED_LOGIN_ATTEMPTS.clear()
    _LOGIN_LOCKOUTS.clear()
    _FAILED_ATTEMPTS.clear()
    _DEVICE_BINDINGS.clear()
    reset_mock_redis()
    yield
    _fallback.requests.clear()
    _perm_cache._store.clear()
    _FAILED_LOGIN_ATTEMPTS.clear()
    _LOGIN_LOCKOUTS.clear()
    _FAILED_ATTEMPTS.clear()
    _DEVICE_BINDINGS.clear()
    reset_mock_redis()


@pytest.fixture(autouse=True)
def stub_email_delivery(monkeypatch):
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: None,
    )


@pytest.fixture(autouse=True)
def mock_redis_client(monkeypatch):
    """Provide a mock Redis client for testing rate limiting and device binding."""
    from test_redis_mock import get_mock_redis

    mock_redis = get_mock_redis()

    # Patch at the source module
    monkeypatch.setattr("core.redis_client.get_redis_client", lambda: mock_redis)

    # Patch in rate_limit module (where it's imported)
    monkeypatch.setattr("rate_limit.get_redis_client", lambda: mock_redis)

    # Patch in child_service module (where it's imported)
    monkeypatch.setattr("services.child_service.get_redis_client", lambda: mock_redis)

    # Patch in auth_service module (where it's imported)
    monkeypatch.setattr("services.auth_service.get_redis_client", lambda: mock_redis)

    yield mock_redis


@pytest.fixture
def create_parent(db):
    from auth import hash_password
    from core.time_utils import db_utc_now
    from models import User
    from plan_service import PLAN_FREE

    def _create_parent(
        *,
        email: str = "parent@example.invalid",
        password: str = "Password123!",
        name: str = "Parent User",
        plan: str = PLAN_FREE,
        is_active: bool = True,
    ):
        user = User(
            email=email,
            password_hash=hash_password(password),
            name=name,
            role="parent",
            plan=plan,
            is_active=is_active,
            email_verified=is_active,
            email_verified_at=db_utc_now() if is_active else None,
            created_at=db_utc_now(),
            updated_at=db_utc_now(),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    return _create_parent


@pytest.fixture
def create_child(db):
    import json
    from datetime import date

    from auth import hash_password
    from models import ChildProfile

    def _create_child(
        *,
        parent_id: int,
        name: str = "Kid",
        age: int = 7,
        picture_password: list[str] | None = None,
        avatar: str = "assets/images/avatars/av1.png",
    ):
        # age is a computed @property on ChildProfile; supply date_of_birth instead.
        # Use Jan 1 so the birthday is always in the past regardless of today's date,
        # making the computed age exactly equal to the requested value.
        today = date.today()
        date_of_birth = date(today.year - age, 1, 1)

        # picture_password_hash stores a bcrypt_json_v1 envelope as a JSON string
        # (column was renamed from picture_password JSON → picture_password_hash String).
        items = picture_password or ["cat", "dog", "apple"]
        canonical = json.dumps(items, separators=(",", ":"), ensure_ascii=True)
        envelope = {
            "scheme": "bcrypt_json_v1",
            "hash": hash_password(canonical),
            "length": len(items),
        }

        child = ChildProfile(
            parent_id=parent_id,
            name=name,
            picture_password_hash=json.dumps(envelope, separators=(",", ":")),
            date_of_birth=date_of_birth,
            avatar=avatar,
        )
        db.add(child)
        db.commit()
        db.refresh(child)
        return child

    return _create_child


@pytest.fixture
def auth_headers():
    from auth import create_access_token

    def _auth_headers(user):
        token = create_access_token(str(user.id), getattr(user, "token_version", 0))
        return {"Authorization": f"Bearer {token}"}

    return _auth_headers


@pytest.fixture
def seed_builtin_rbac(db):
    from admin_models import Permission, Role, RolePermission
    from routers.admin_seed import PERMISSION_DEFS, ROLE_DEFS

    def _seed_builtin_rbac():
        permission_by_name: dict[str, Permission] = {}
        for permission_name, description in PERMISSION_DEFS:
            permission = db.query(Permission).filter(Permission.name == permission_name).first()
            if permission is None:
                permission = Permission(name=permission_name, description=description)
                db.add(permission)
                db.flush()
            permission_by_name[permission_name] = permission

        for role_name, permission_names in ROLE_DEFS.items():
            role = db.query(Role).filter(Role.name == role_name).first()
            if role is None:
                role = Role(name=role_name, description=f"Built-in role: {role_name}")
                db.add(role)
                db.flush()

            existing_permission_ids = {
                mapping.permission_id
                for mapping in db.query(RolePermission)
                .filter(RolePermission.role_id == role.id)
                .all()
            }
            for permission_name in permission_names:
                permission = permission_by_name[permission_name]
                if permission.id not in existing_permission_ids:
                    db.add(RolePermission(role_id=role.id, permission_id=permission.id))

        db.commit()

    return _seed_builtin_rbac


@pytest.fixture
def create_admin(db):
    from admin_models import AdminUser, AdminUserRole, Role
    from auth import hash_password

    def _create_admin(
        *,
        email: str,
        password: str = "AdminPass123!",
        role_names: list[str] | None = None,
        role_ids: list[int] | None = None,
        is_active: bool = True,
    ):
        admin = AdminUser(
            email=email,
            password_hash=hash_password(password),
            name=email.split("@", 1)[0],
            is_active=is_active,
            token_version=0,
        )
        db.add(admin)
        db.flush()

        for role_name in role_names or []:
            role = db.query(Role).filter(Role.name == role_name).one()
            db.add(AdminUserRole(admin_user_id=admin.id, role_id=role.id))

        for role_id in role_ids or []:
            db.add(AdminUserRole(admin_user_id=admin.id, role_id=role_id))

        db.commit()
        db.refresh(admin)
        return admin

    return _create_admin


@pytest.fixture
def admin_headers():
    from admin_auth import create_admin_access_token

    def _admin_headers(admin):
        token = create_admin_access_token(admin.id, getattr(admin, "token_version", 0))
        return {"Authorization": f"Bearer {token}"}

    return _admin_headers

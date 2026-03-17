import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

# Ensure tests have deterministic auth/admin env defaults before app imports.
os.environ.setdefault("SECRET_KEY", "TEST_ONLY_SECRET")
os.environ.setdefault("KINDER_JWT_SECRET", os.environ["SECRET_KEY"])
os.environ.setdefault("ENABLE_ADMIN_SEED_ENDPOINT", "true")
os.environ.setdefault("ADMIN_SEED_SECRET", "TEST_ONLY_SECRET")
os.environ.setdefault("ADMIN_SEED_PASSWORD", "CHANGE_ME")
os.environ.setdefault("ADMIN_SEED_EMAIL", "change-me@example.invalid")
os.environ.setdefault("ADMIN_SEED_NAME", "DEV ONLY ADMIN")
os.environ.setdefault("SKIP_SCHEMA_VERIFY", "true")


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
    from database import SessionLocal

    connection = test_db.connect()
    transaction = connection.begin()
    session = SessionLocal(bind=connection)
    yield session
    session.close()
    if transaction.is_active:
        transaction.rollback()
    connection.close()


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
    # Keep tests independent if/when route dependencies start using this state.
    from rate_limit import rate_limiter
    from services.child_service import _DEVICE_BINDINGS, _FAILED_ATTEMPTS

    rate_limiter.requests.clear()
    _FAILED_ATTEMPTS.clear()
    _DEVICE_BINDINGS.clear()
    yield
    rate_limiter.requests.clear()
    _FAILED_ATTEMPTS.clear()
    _DEVICE_BINDINGS.clear()


@pytest.fixture
def create_parent(db):
    from auth import hash_password
    from core.time_utils import db_utc_now
    from models import User
    from plan_service import PLAN_FREE

    def _create_parent(
        *,
        email: str = "parent@example.com",
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
    from models import ChildProfile

    def _create_child(
        *,
        parent_id: int,
        name: str = "Kid",
        age: int = 7,
        picture_password: list[str] | None = None,
        avatar: str = "assets/images/avatars/av1.png",
    ):
        child = ChildProfile(
            parent_id=parent_id,
            name=name,
            picture_password=picture_password or ["cat", "dog", "apple"],
            age=age,
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

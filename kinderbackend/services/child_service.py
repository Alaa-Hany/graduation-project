import logging
import os
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import JWTError
from sqlalchemy import func
from sqlalchemy.orm import Session

from auth import create_token, decode_token
from core.errors import forbidden, http_error, not_found, unauthorized, unprocessable
from core.time_utils import db_utc_now, utc_now
from core.validators import (
    normalize_email,
    resolve_child_age,
    validate_child_age,
    validate_email_domain,
    validate_picture_password_length,
)
from deps import decode_bearer
from models import ChildProfile, User
from plan_service import PLAN_LIMITS, get_user_plan
from schemas.auth import (
    ChildChangePasswordIn,
    ChildLoginIn,
    ChildRegisterIn,
    ChildSessionValidateIn,
)
from schemas.children import ChildCreate, ChildUpdate
from serializers import child_to_json

logger = logging.getLogger(__name__)

PREMIUM_PRICE_USD = 10

_FAILED_ATTEMPTS: dict[str, list[float]] = defaultdict(list)
_DEVICE_BINDINGS: dict[int, str] = {}


class ChildService:
    def _rate_limit_window_seconds(self) -> int:
        return max(int(os.getenv("CHILD_AUTH_RATE_LIMIT_WINDOW_SECONDS", "300")), 30)

    def _rate_limit_max_attempts(self) -> int:
        return max(int(os.getenv("CHILD_AUTH_RATE_LIMIT_MAX_ATTEMPTS", "5")), 1)

    def _suspicious_threshold(self) -> int:
        return max(int(os.getenv("CHILD_AUTH_SUSPICIOUS_THRESHOLD", "3")), 1)

    def _session_ttl_minutes(self) -> int:
        return max(int(os.getenv("CHILD_SESSION_TTL_MINUTES", "120")), 5)

    def _device_binding_enabled(self) -> bool:
        return os.getenv("CHILD_AUTH_DEVICE_BINDING_ENABLED", "false").strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }

    def _device_id_required(self) -> bool:
        return os.getenv("CHILD_AUTH_REQUIRE_DEVICE_ID", "false").strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }

    def _cleanup_attempts(self, key: str) -> None:
        now = time.time()
        window_start = now - self._rate_limit_window_seconds()
        _FAILED_ATTEMPTS[key] = [ts for ts in _FAILED_ATTEMPTS[key] if ts > window_start]

    def _attempt_key(self, *, child_id: int, client_ip: str) -> str:
        return f"{child_id}:{client_ip or 'unknown'}"

    def _record_failed_attempt(
        self,
        *,
        child_id: int,
        client_ip: str,
        reason: str,
        user_agent: str | None,
        device_id: str | None,
    ) -> None:
        key = self._attempt_key(child_id=child_id, client_ip=client_ip)
        _FAILED_ATTEMPTS[key].append(time.time())
        self._cleanup_attempts(key)
        count = len(_FAILED_ATTEMPTS[key])
        suspicious = count >= self._suspicious_threshold()

        logger.warning(
            "child_auth_failed child_id=%s ip=%s reason=%s attempts_in_window=%s suspicious=%s device_id=%s user_agent=%s",
            child_id,
            client_ip or "unknown",
            reason,
            count,
            suspicious,
            device_id,
            user_agent,
        )

    def _enforce_child_rate_limit(
        self,
        *,
        child_id: int,
        client_ip: str,
        user_agent: str | None,
        device_id: str | None,
    ) -> None:
        key = self._attempt_key(child_id=child_id, client_ip=client_ip)
        self._cleanup_attempts(key)
        attempts = len(_FAILED_ATTEMPTS[key])
        limit = self._rate_limit_max_attempts()
        if attempts >= limit:
            logger.warning(
                "child_auth_rate_limited child_id=%s ip=%s attempts_in_window=%s limit=%s",
                child_id,
                client_ip or "unknown",
                attempts,
                limit,
            )
            self._record_failed_attempt(
                child_id=child_id,
                client_ip=client_ip,
                reason="RATE_LIMIT_EXCEEDED",
                user_agent=user_agent,
                device_id=device_id,
            )
            raise http_error(
                status_code=429,
                message="Too many failed child login attempts. Try again later.",
                code="CHILD_AUTH_RATE_LIMIT_EXCEEDED",
                extra={"retry_after_seconds": self._rate_limit_window_seconds()},
            )

    def _bind_or_validate_device(
        self,
        *,
        child_id: int,
        device_id: str | None,
        client_ip: str,
        user_agent: str | None,
    ) -> None:
        if not self._device_binding_enabled():
            return

        if not device_id:
            if self._device_id_required():
                self._record_failed_attempt(
                    child_id=child_id,
                    client_ip=client_ip,
                    reason="DEVICE_ID_REQUIRED",
                    user_agent=user_agent,
                    device_id=device_id,
                )
                raise unprocessable("Device ID is required for child login")
            return

        bound_device = _DEVICE_BINDINGS.get(child_id)
        if bound_device is None:
            _DEVICE_BINDINGS[child_id] = device_id
            logger.info("child_auth_device_bound child_id=%s device_id=%s", child_id, device_id)
            return

        if bound_device != device_id:
            self._record_failed_attempt(
                child_id=child_id,
                client_ip=client_ip,
                reason="DEVICE_BINDING_MISMATCH",
                user_agent=user_agent,
                device_id=device_id,
            )
            raise forbidden("This child account is bound to a different device")

    def resolve_parent(
        self,
        *,
        parent_email: Optional[str],
        authorization: Optional[str],
        db: Session,
    ) -> User:
        if parent_email:
            normalized_email = normalize_email(parent_email)
            parent = db.query(User).filter(func.lower(User.email) == normalized_email).first()
            if not parent:
                raise not_found("Parent not found")
            return parent

        parent_id = decode_bearer(authorization)
        if not parent_id:
            raise unauthorized("Invalid token payload")

        parent = db.query(User).filter(User.id == int(parent_id)).first()
        if not parent:
            raise not_found("Parent not found")
        token = authorization.replace("Bearer ", "").strip() if authorization else ""
        try:
            payload = decode_token(token)
        except JWTError:
            raise unauthorized("Invalid token")

        try:
            token_version = int(payload.get("token_version"))
        except (TypeError, ValueError):
            raise unauthorized("Token has been revoked")

        if token_version != int(parent.token_version or 0):
            raise unauthorized("Token has been revoked")
        return parent

    def enforce_child_limit(self, *, parent: User, db: Session) -> None:
        plan = get_user_plan(parent)
        limit = PLAN_LIMITS.get(plan)
        if limit is None:
            return

        child_count = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.parent_id == parent.id,
                ChildProfile.deleted_at.is_(None),
            )
            .count()
        )
        if child_count >= limit:
            raise http_error(
                status_code=402,
                message=f"Plan limit reached ({limit}). Upgrade to add more children.",
                code="CHILD_LIMIT_REACHED",
                extra={
                    "plan": plan,
                    "limit": limit,
                    "current_count": child_count,
                    "price_usd": PREMIUM_PRICE_USD,
                    "currency": "USD",
                },
            )

    def ensure_unique_child_name(self, *, parent: User, name: str, db: Session) -> None:
        existing = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.parent_id == parent.id,
                ChildProfile.name == name,
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if existing:
            raise http_error(
                status_code=400,
                message="Child name already exists for this parent.",
                code="CHILD_NAME_EXISTS",
            )

    def create_child_profile(
        self,
        *,
        payload: ChildCreate,
        authorization: Optional[str],
        db: Session,
    ) -> dict:
        if payload.parent_email:
            validate_email_domain(normalize_email(payload.parent_email))

        resolved_age = resolve_child_age(payload.age, payload.date_of_birth)
        validate_child_age(resolved_age)
        parent = self.resolve_parent(
            parent_email=payload.parent_email,
            authorization=authorization,
            db=db,
        )
        self.enforce_child_limit(parent=parent, db=db)
        self.ensure_unique_child_name(parent=parent, name=payload.name, db=db)

        child = ChildProfile(
            parent_id=parent.id,
            name=payload.name,
            picture_password=payload.picture_password,
            date_of_birth=payload.date_of_birth,
            age=resolved_age,
            avatar=payload.avatar,
        )
        db.add(child)
        db.commit()
        db.refresh(child)
        return {"child": child_to_json(child)}

    def list_parent_children(self, *, parent: User, db: Session) -> dict:
        children = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.parent_id == parent.id,
                ChildProfile.deleted_at.is_(None),
            )
            .all()
        )
        return {"children": [child_to_json(child) for child in children]}

    def delete_child_profile(self, *, child_id: int, parent: User, db: Session) -> dict:
        child = (
            db.query(ChildProfile)
            .filter(ChildProfile.id == child_id, ChildProfile.deleted_at.is_(None))
            .first()
        )
        if not child:
            raise not_found("Child not found")
        if child.parent_id != parent.id:
            raise forbidden("Forbidden")

        child.deleted_at = db_utc_now()
        child.is_active = False
        db.add(child)
        db.commit()
        return {"success": True}

    def update_child_profile(
        self,
        *,
        child_id: int,
        payload: ChildUpdate,
        parent: User,
        db: Session,
    ) -> dict:
        child = (
            db.query(ChildProfile)
            .filter(ChildProfile.id == child_id, ChildProfile.deleted_at.is_(None))
            .first()
        )
        if not child:
            raise not_found("Child not found")
        if child.parent_id != parent.id:
            raise forbidden("Forbidden")

        if payload.name is not None:
            child.name = payload.name
        if payload.picture_password is not None:
            child.picture_password = payload.picture_password
        if payload.date_of_birth is not None:
            child.date_of_birth = payload.date_of_birth
        if payload.age is not None or payload.date_of_birth is not None:
            resolved_age = resolve_child_age(payload.age, payload.date_of_birth)
            validate_child_age(resolved_age)
            child.age = resolved_age
        if payload.avatar is not None:
            child.avatar = payload.avatar

        child.updated_at = db_utc_now()
        db.add(child)
        db.commit()
        db.refresh(child)
        return {"child": child_to_json(child)}

    def register_child(self, *, payload: ChildRegisterIn, db: Session) -> dict:
        parent_email = normalize_email(payload.parent_email)
        validate_email_domain(parent_email)
        parent = db.query(User).filter(func.lower(User.email) == parent_email).first()
        if not parent:
            raise not_found("Parent not found")

        resolved_age = resolve_child_age(payload.age, payload.date_of_birth)
        validate_child_age(resolved_age)
        self.enforce_child_limit(parent=parent, db=db)
        self.ensure_unique_child_name(parent=parent, name=payload.name, db=db)

        child = ChildProfile(
            parent_id=parent.id,
            name=payload.name,
            picture_password=payload.picture_password,
            date_of_birth=payload.date_of_birth,
            age=resolved_age,
            avatar=payload.avatar,
        )
        db.add(child)
        db.commit()
        db.refresh(child)
        return {"child": child_to_json(child)}

    def _resolve_device_id(self, payload: ChildLoginIn) -> str | None:
        device_id = (payload.device_id or "").strip()
        if device_id:
            return device_id
        fingerprint = (payload.device_fingerprint or "").strip()
        return fingerprint or None

    def _build_child_session(self, *, child: ChildProfile, device_id: str | None) -> dict:
        ttl_minutes = self._session_ttl_minutes()
        expires_at = utc_now() + timedelta(minutes=ttl_minutes)
        token = create_token(
            str(child.id),
            minutes=ttl_minutes,
            extra_claims={
                "token_type": "child_session",
                "child_id": child.id,
                "child_name": child.name,
                **({"device_id": device_id} if device_id else {}),
            },
        )
        return {
            "session_token": token,
            "session_expires_at": expires_at.isoformat(),
            "session_ttl_minutes": ttl_minutes,
        }

    def login_child(
        self,
        *,
        payload: ChildLoginIn,
        db: Session,
        client_ip: str = "unknown",
        user_agent: str | None = None,
    ) -> dict:
        device_id = self._resolve_device_id(payload)
        self._enforce_child_rate_limit(
            child_id=payload.child_id,
            client_ip=client_ip,
            user_agent=user_agent,
            device_id=device_id,
        )

        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == payload.child_id,
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if not child:
            self._record_failed_attempt(
                child_id=payload.child_id,
                client_ip=client_ip,
                reason="CHILD_NOT_FOUND",
                user_agent=user_agent,
                device_id=device_id,
            )
            raise not_found("Child not found")

        normalized_name = payload.name.strip().lower()
        child_name = (child.name or "").strip().lower()
        if not normalized_name or normalized_name != child_name:
            self._record_failed_attempt(
                child_id=child.id,
                client_ip=client_ip,
                reason="INVALID_CHILD_NAME",
                user_agent=user_agent,
                device_id=device_id,
            )
            raise unauthorized("Invalid credentials")

        stored = child.picture_password or []
        if stored != payload.picture_password:
            self._record_failed_attempt(
                child_id=child.id,
                client_ip=client_ip,
                reason="INVALID_PICTURE_PASSWORD",
                user_agent=user_agent,
                device_id=device_id,
            )
            raise unauthorized("Invalid picture password")

        self._bind_or_validate_device(
            child_id=child.id,
            device_id=device_id,
            client_ip=client_ip,
            user_agent=user_agent,
        )

        key = self._attempt_key(child_id=child.id, client_ip=client_ip)
        if key in _FAILED_ATTEMPTS:
            del _FAILED_ATTEMPTS[key]

        session_payload = self._build_child_session(child=child, device_id=device_id)
        logger.info(
            "child_auth_success child_id=%s ip=%s device_id=%s",
            child.id,
            client_ip,
            device_id,
        )

        return {
            "success": True,
            "child_id": child.id,
            "name": child.name,
            **session_payload,
        }

    def validate_child_session(
        self,
        *,
        payload: ChildSessionValidateIn,
        db: Session,
    ) -> dict:
        try:
            claims = decode_token(payload.session_token)
        except JWTError:
            raise unauthorized("Invalid or expired child session")

        token_type = claims.get("token_type")
        if token_type != "child_session":
            raise unauthorized("Invalid child session token type")

        child_id = claims.get("child_id") or claims.get("sub")
        if child_id is None:
            raise unauthorized("Invalid child session payload")

        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == int(child_id),
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if not child:
            raise not_found("Child not found")

        token_device = claims.get("device_id")
        if token_device and payload.device_id and token_device != payload.device_id:
            raise unauthorized("Child session is bound to a different device")

        exp = claims.get("exp")
        exp_iso = None
        if exp is not None:
            exp_iso = datetime.fromtimestamp(exp, tz=timezone.utc).isoformat()

        return {
            "success": True,
            "child_id": child.id,
            "name": child.name,
            "session_expires_at": exp_iso,
        }

    def change_child_password(self, *, payload: ChildChangePasswordIn, db: Session) -> dict:
        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == payload.child_id,
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if not child:
            raise not_found("Child not found")

        normalized_name = payload.name.strip().lower()
        child_name = (child.name or "").strip().lower()
        if not normalized_name or normalized_name != child_name:
            raise unauthorized("Invalid credentials")

        stored = child.picture_password or []
        if stored != payload.current_picture_password:
            raise unauthorized("Current picture password is incorrect")

        validate_picture_password_length(payload.new_picture_password, length=3)

        child.picture_password = payload.new_picture_password
        child.updated_at = db_utc_now()
        db.add(child)
        db.commit()
        db.refresh(child)

        return {"success": True, "message": "Picture password changed successfully"}


child_service = ChildService()


def resolve_parent(parent_email: Optional[str], authorization: Optional[str], db: Session) -> User:
    return child_service.resolve_parent(
        parent_email=parent_email,
        authorization=authorization,
        db=db,
    )


def enforce_child_limit(parent: User, db: Session) -> None:
    return child_service.enforce_child_limit(parent=parent, db=db)


def ensure_unique_child_name(parent: User, name: str, db: Session) -> None:
    return child_service.ensure_unique_child_name(parent=parent, name=name, db=db)


def create_child_profile(
    payload: ChildCreate,
    authorization: Optional[str],
    db: Session,
) -> dict:
    return child_service.create_child_profile(
        payload=payload,
        authorization=authorization,
        db=db,
    )


def list_parent_children(parent: User, db: Session) -> dict:
    return child_service.list_parent_children(parent=parent, db=db)


def delete_child_profile(child_id: int, parent: User, db: Session) -> dict:
    return child_service.delete_child_profile(child_id=child_id, parent=parent, db=db)


def update_child_profile(child_id: int, payload: ChildUpdate, parent: User, db: Session) -> dict:
    return child_service.update_child_profile(
        child_id=child_id,
        payload=payload,
        parent=parent,
        db=db,
    )


def register_child(payload: ChildRegisterIn, db: Session) -> dict:
    return child_service.register_child(payload=payload, db=db)


def login_child(
    payload: ChildLoginIn,
    db: Session,
    *,
    client_ip: str = "unknown",
    user_agent: str | None = None,
) -> dict:
    return child_service.login_child(
        payload=payload,
        db=db,
        client_ip=client_ip,
        user_agent=user_agent,
    )


def validate_child_session(payload: ChildSessionValidateIn, db: Session) -> dict:
    return child_service.validate_child_session(payload=payload, db=db)


def change_child_password(payload: ChildChangePasswordIn, db: Session) -> dict:
    return child_service.change_child_password(payload=payload, db=db)

import json
import logging
import os
import time
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

from jwt import PyJWTError as JWTError
from sqlalchemy.orm import Session

from auth import create_token, decode_token, hash_password, verify_password
from core.errors import forbidden, http_error, not_found, unauthorized, unprocessable
from core.redis_client import get_redis_client
from core.system_settings import get_default_child_limit
from core.time_utils import db_utc_now, utc_now
from core.validators import resolve_child_age, validate_child_age, validate_picture_password_length
from models import ChildProfile, User
from plan_service import PLAN_FREE, PLAN_LIMITS, get_user_plan
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
PICTURE_PASSWORD_HASH_SCHEME = "bcrypt_json_v1"


# Redis key helpers — module-level dicts removed; state lives in Redis.
def _child_failed_key(child_id: int, client_ip: str) -> str:
    return f"child:failed:{child_id}:{client_ip or 'unknown'}"


def _child_device_key(child_id: int) -> str:
    return f"child:device:{child_id}"


_FAILED_ATTEMPTS: dict[str, list[float]] = defaultdict(list)
_DEVICE_BINDINGS: dict[int, str] = {}


class ChildService:
    def _canonical_picture_password(self, picture_password: list[str]) -> str:
        validate_picture_password_length(picture_password, length=3)
        return json.dumps(picture_password, separators=(",", ":"), ensure_ascii=True)

    def _hash_picture_password(self, picture_password: list[str]) -> dict[str, str | int]:
        return {
            "scheme": PICTURE_PASSWORD_HASH_SCHEME,
            "hash": hash_password(self._canonical_picture_password(picture_password)),
            "length": len(picture_password),
        }

    def picture_password_length(self, stored_password: object) -> int:
        if isinstance(stored_password, dict):
            length = stored_password.get("length")
            if isinstance(length, int):
                return length
        return 0

    def _verify_picture_password(
        self,
        *,
        stored_password: object,
        provided_password: list[str],
    ) -> bool:
        # Legacy plaintext-list format removed; all passwords are bcrypt_json_v1
        # after migration c8d9e0f1a2b3.
        if isinstance(stored_password, dict):
            scheme = stored_password.get("scheme")
            password_hash = stored_password.get("hash")
            if scheme == PICTURE_PASSWORD_HASH_SCHEME and isinstance(password_hash, str):
                return verify_password(
                    self._canonical_picture_password(provided_password),
                    password_hash,
                )
        return False

    def _ensure_parent_matches_payload_email(
        self,
        *,
        parent: User,
        parent_email: str | None,
    ) -> None:
        if parent_email is None:
            return
        normalized_payload_email = parent_email.strip().lower()
        normalized_parent_email = (parent.email or "").strip().lower()
        if normalized_payload_email == normalized_parent_email:
            return
        logger.warning(
            "child_register_parent_email_mismatch parent_id=%s authenticated_email=%s payload_email=%s",
            parent.id,
            normalized_parent_email,
            normalized_payload_email,
        )
        raise forbidden("Parent email does not match authenticated parent")

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

    def _record_failed_attempt(
        self,
        *,
        child_id: int,
        client_ip: str,
        reason: str,
        user_agent: str | None,
        device_id: str | None,
    ) -> None:
        """Increment the Redis failure counter and log."""
        rc = get_redis_client()
        count = 0
        if rc is None:
            key = _child_failed_key(child_id, client_ip)
            now = time.time()
            window_start = now - self._rate_limit_window_seconds()
            attempts = [ts for ts in _FAILED_ATTEMPTS[key] if ts > window_start]
            attempts.append(now)
            _FAILED_ATTEMPTS[key] = attempts
            count = len(attempts)
        else:
            rkey = _child_failed_key(child_id, client_ip)
            window = self._rate_limit_window_seconds()
            try:
                pipe = rc.pipeline()
                pipe.incr(rkey)
                pipe.expire(rkey, window, nx=True)
                count, _ = pipe.execute()
                count = int(count)
            except Exception as exc:
                logger.error("Redis child failure INCR failed (%s)", exc)

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
        """Raise 429 if the failure counter for this child+IP exceeds the limit."""
        rc = get_redis_client()
        attempts = 0
        if rc is None:
            key = _child_failed_key(child_id, client_ip)
            window_start = time.time() - self._rate_limit_window_seconds()
            _FAILED_ATTEMPTS[key] = [ts for ts in _FAILED_ATTEMPTS[key] if ts > window_start]
            attempts = len(_FAILED_ATTEMPTS[key])
        else:
            rkey = _child_failed_key(child_id, client_ip)
            try:
                attempts = int(rc.get(rkey) or 0)
            except Exception as exc:
                logger.error("Redis child rate-limit GET failed (%s); skipping check", exc)
                return

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

        rc = get_redis_client()
        if rc is None:
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
            return

        dkey = _child_device_key(child_id)
        try:
            bound_device = rc.get(dkey)
        except Exception as exc:
            logger.error("Redis device binding GET failed (%s); skipping binding check", exc)
            return

        if bound_device is None:
            try:
                rc.set(dkey, device_id)  # no TTL — binding is permanent until explicitly cleared
            except Exception as exc:
                logger.error("Redis device binding SET failed (%s)", exc)
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

    def enforce_child_limit(self, *, parent: User, db: Session) -> None:
        plan = get_user_plan(parent)
        limit = PLAN_LIMITS.get(plan)
        # The FREE plan limit is configurable from the admin system settings
        # ("defaults.default_child_limit"); the paid plans keep their fixed caps.
        if plan == PLAN_FREE:
            configured = get_default_child_limit(db)
            if configured is not None:
                limit = configured
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
        parent: User,
        db: Session,
    ) -> dict:
        resolved_age = resolve_child_age(payload.age, payload.date_of_birth)
        validate_child_age(resolved_age)
        self._ensure_parent_matches_payload_email(
            parent=parent,
            parent_email=payload.parent_email,
        )
        self.enforce_child_limit(parent=parent, db=db)
        self.ensure_unique_child_name(parent=parent, name=payload.name, db=db)

        child = ChildProfile(
            parent_id=parent.id,
            name=payload.name,
            picture_password=self._hash_picture_password(payload.picture_password),
            date_of_birth=payload.date_of_birth,
            avatar=payload.avatar,
        )
        if payload.age is not None and payload.date_of_birth is None:
            # TODO: callers should pass a real date_of_birth instead of an integer age
            today = date.today()
            child.date_of_birth = date(today.year - int(payload.age), 1, 1)
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
            child.picture_password = self._hash_picture_password(payload.picture_password)
        if payload.date_of_birth is not None:
            child.date_of_birth = payload.date_of_birth
        if payload.age is not None:
            if payload.date_of_birth is None:
                # TODO: callers should pass a real date_of_birth instead of an integer age
                today = date.today()
                child.date_of_birth = date(today.year - int(payload.age), 1, 1)
        if payload.age is not None or payload.date_of_birth is not None:
            resolved_age = resolve_child_age(payload.age, payload.date_of_birth)
            validate_child_age(resolved_age)
            # Age is now computed from date_of_birth; validation still applies
        if payload.avatar is not None:
            child.avatar = payload.avatar

        child.updated_at = db_utc_now()
        db.add(child)
        db.commit()
        db.refresh(child)
        return {"child": child_to_json(child)}

    def register_child(self, *, payload: ChildRegisterIn, parent: User, db: Session) -> dict:
        from schemas.children import ChildCreate

        return self.create_child_profile(
            payload=ChildCreate(**payload.model_dump()),
            parent=parent,
            db=db,
        )

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
            raise http_error(
                status_code=401,
                message="Invalid credentials",
                code="CHILD_INVALID_NAME",
            )

        stored_password = child.picture_password or []
        if not self._verify_picture_password(
            stored_password=stored_password,
            provided_password=payload.picture_password,
        ):
            self._record_failed_attempt(
                child_id=child.id,
                client_ip=client_ip,
                reason="INVALID_PICTURE_PASSWORD",
                user_agent=user_agent,
                device_id=device_id,
            )
            raise http_error(
                status_code=401,
                message="Invalid picture password",
                code="CHILD_INVALID_PICTURE",
            )

        self._bind_or_validate_device(
            child_id=child.id,
            device_id=device_id,
            client_ip=client_ip,
            user_agent=user_agent,
        )

        rc = get_redis_client()
        if rc is not None:
            try:
                rc.delete(_child_failed_key(child.id, client_ip))
            except Exception as exc:
                logger.error("Redis child failure-key DELETE failed (%s)", exc)
        else:
            _FAILED_ATTEMPTS.pop(_child_failed_key(child.id, client_ip), None)

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
        request_device = (payload.device_id or "").strip() or None
        if token_device and not request_device:
            raise unauthorized("Device ID is required for this child session")
        if token_device and token_device != request_device:
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

        stored_password = child.picture_password or []
        if not self._verify_picture_password(
            stored_password=stored_password,
            provided_password=payload.current_picture_password,
        ):
            raise unauthorized("Current picture password is incorrect")

        validate_picture_password_length(payload.new_picture_password, length=3)

        child.picture_password = self._hash_picture_password(payload.new_picture_password)
        child.updated_at = db_utc_now()
        db.add(child)
        db.commit()
        db.refresh(child)

        return {"success": True, "message": "Picture password changed successfully"}


child_service = ChildService()


def enforce_child_limit(parent: User, db: Session) -> None:
    return child_service.enforce_child_limit(parent=parent, db=db)


def ensure_unique_child_name(parent: User, name: str, db: Session) -> None:
    return child_service.ensure_unique_child_name(parent=parent, name=name, db=db)


def create_child_profile(
    payload: ChildCreate,
    parent: User,
    db: Session,
) -> dict:
    return child_service.create_child_profile(
        payload=payload,
        parent=parent,
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


def register_child(payload: ChildRegisterIn, parent: User, db: Session) -> dict:
    return child_service.register_child(payload=payload, parent=parent, db=db)


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

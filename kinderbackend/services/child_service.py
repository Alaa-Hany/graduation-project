import json
import logging
import os
import secrets
import time
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

from jwt import PyJWTError as JWTError
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from auth import create_token, decode_token, hash_password, verify_password
from core.errors import bad_request, forbidden, http_error, not_found, unauthorized, unprocessable
from core.message_catalog import AuthMessages
from core.redis_client import get_redis_client
from core.system_settings import get_default_child_limit
from core.time_utils import db_utc_now, ensure_utc, utc_now
from core.validators import (
    normalize_email,
    resolve_child_age,
    validate_child_age,
    validate_picture_password_length,
)
from models import (
    ChildActivityEvent,
    ChildDailyActivitySummary,
    ChildProfile,
    ChildSessionLog,
    User,
)
from plan_service import PLAN_FREE, PLAN_LIMITS, get_user_plan
from schemas.auth import (
    ChildChangePasswordIn,
    ChildForgotPasswordIn,
    ChildLoginIn,
    ChildRegisterIn,
    ChildResetPicturePasswordIn,
    ChildSessionValidateIn,
)
from schemas.children import ChildCreate, ChildUpdate
from serializers import child_to_json
from services.email_delivery_service import email_delivery_service

logger = logging.getLogger(__name__)

PREMIUM_PRICE_USD = 10
PICTURE_PASSWORD_HASH_SCHEME = "bcrypt_json_v1"

# Event types that count as a completed activity for progress aggregation.
# Mirrors COMPLETION_EVENT_TYPES in the analytics services.
_COMPLETION_EVENT_TYPES = ("activity_completed", "lesson_completed")

# XP→level mapping, mirrors LevelThresholds in the Flutter client
# (lib/core/models/achievement.dart): a new level every 1000 XP, capped at 10.
_XP_PER_LEVEL = 1000
_MAX_LEVEL = 10


def _level_for_xp(xp: int) -> int:
    """Return the 1-based level for a total XP, matching the client formula."""
    level = (max(xp, 0) // _XP_PER_LEVEL) + 1
    return max(1, min(level, _MAX_LEVEL))


def _current_streak(active_dates: list[date]) -> int:
    """Length of the consecutive-day run ending at the most recent active day.

    Mirrors the client's stored streak, which counts back from the latest day
    the child was active and only breaks on a gap of more than one day. We anchor
    on the latest active day (rather than "today") because the client's stored
    streak does not decay until the next activity.
    """
    if not active_dates:
        return 0
    ordered = sorted(set(active_dates), reverse=True)
    streak = 1
    previous = ordered[0]
    for day in ordered[1:]:
        if (previous - day).days == 1:
            streak += 1
            previous = day
        else:
            break
    return streak


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
            # The child-create UI collects only an integer age (5-12), never a
            # birth date, so we approximate date_of_birth as Jan 1 of the birth
            # year. This keeps the displayed age consistent year-over-year;
            # callers may pass an explicit date_of_birth when one is available.
            today = date.today()
            child.date_of_birth = date(today.year - int(payload.age), 1, 1)
        db.add(child)
        db.commit()
        db.refresh(child)
        return {"child": child_to_json(child)}

    def _progress_by_child(self, *, db: Session, child_ids: list[int]) -> dict[int, dict]:
        """Aggregate all-time progress per child from the analytics tables.

        Returns ``{child_id: {xp, level, streak, total_time_spent,
        activities_completed}}``. Computed from the same events/sessions the
        child app already streams to the backend, so no extra columns or
        client changes are needed.
        """
        progress = {
            cid: {
                "xp": 0,
                "level": 1,
                "streak": 0,
                "total_time_spent": 0,
                "activities_completed": 0,
            }
            for cid in child_ids
        }
        if not child_ids:
            return progress

        # XP (sum of points on completion events) + activity count, per child.
        event_rows = (
            db.query(
                ChildActivityEvent.child_id,
                func.coalesce(
                    func.sum(
                        case(
                            (
                                ChildActivityEvent.event_type.in_(_COMPLETION_EVENT_TYPES),
                                ChildActivityEvent.points,
                            ),
                            else_=0,
                        )
                    ),
                    0,
                ).label("xp"),
                func.count(
                    case((ChildActivityEvent.event_type.in_(_COMPLETION_EVENT_TYPES), 1))
                ).label("activities"),
            )
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.archived_at.is_(None),
            )
            .group_by(ChildActivityEvent.child_id)
            .all()
        )
        for row in event_rows:
            entry = progress[row.child_id]
            entry["xp"] = int(row.xp or 0)
            entry["activities_completed"] = int(row.activities or 0)

        # Total screen time (minutes) from session logs, per child.
        session_rows = (
            db.query(
                ChildSessionLog.child_id,
                func.coalesce(func.sum(ChildSessionLog.duration_seconds), 0).label("seconds"),
            )
            .filter(
                ChildSessionLog.child_id.in_(child_ids),
                ChildSessionLog.archived_at.is_(None),
            )
            .group_by(ChildSessionLog.child_id)
            .all()
        )
        for row in session_rows:
            progress[row.child_id]["total_time_spent"] = int((row.seconds or 0) // 60)

        # Active days for the streak, from the daily-summary rollup.
        date_rows = (
            db.query(
                ChildDailyActivitySummary.child_id,
                ChildDailyActivitySummary.summary_date,
            )
            .filter(
                ChildDailyActivitySummary.child_id.in_(child_ids),
                ChildDailyActivitySummary.archived_at.is_(None),
            )
            .all()
        )
        dates_by_child: dict[int, list[date]] = defaultdict(list)
        for child_id, summary_date in date_rows:
            if summary_date is not None:
                dates_by_child[child_id].append(summary_date)

        for cid in child_ids:
            entry = progress[cid]
            entry["streak"] = _current_streak(dates_by_child.get(cid, []))
            entry["level"] = _level_for_xp(entry["xp"])

        return progress

    def _recent_activity_records(
        self, *, db: Session, child_id: int, limit: int = 1000
    ) -> list[dict]:
        """Return the child's completion history for local-first recovery.

        Child mode computes the daily goal AND the "done" badges on every lesson,
        game and story from records in its local Hive box only
        (``getTodayProgress`` for today's goal, ``completedActivityIds`` for the
        all-time badges). After a logout/login cycle, on a fresh device, or when
        the web build drops its storage, that box can be empty even though the
        backend still holds every event the child streamed via
        ``/analytics/events``. We return the full completion history (newest
        first, capped) so the client can rebuild both the daily goal and the
        all-time completion badges.

        Each event carries the original ``client_record_id`` and ``activity_id``
        from its ``metadata_json`` so the client can re-seed records under the
        SAME id it used locally — that keeps the restore idempotent (no
        duplicates / no inflated daily goal) even when local storage survived.
        """
        rows = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id == child_id,
                ChildActivityEvent.archived_at.is_(None),
                ChildActivityEvent.event_type.in_(_COMPLETION_EVENT_TYPES),
            )
            .order_by(ChildActivityEvent.occurred_at.desc())
            .limit(limit)
            .all()
        )
        records = []
        for row in rows:
            occurred = ensure_utc(row.occurred_at)
            meta = row.metadata_json if isinstance(row.metadata_json, dict) else {}
            # The badge key the client checks against is the activity_id it sent
            # in metadata_json; lesson_id mirrors it for lessons only.
            activity_id = (
                meta.get("activity_id") or row.lesson_id or row.activity_name or f"event_{row.id}"
            )
            # The human-readable title the child saw. Without it, a restored
            # record falls back to rendering the raw (often numeric CMS)
            # activity_id in the history feed.
            activity_name = row.activity_name or meta.get("activity_name")
            records.append(
                {
                    "event_id": row.id,
                    "client_record_id": meta.get("client_record_id"),
                    "activity_id": activity_id,
                    "activity_name": activity_name,
                    "event_type": row.event_type,
                    "points": int(row.points or 0),
                    "duration_seconds": int(row.duration_seconds or 0),
                    "occurred_at": occurred.isoformat() if occurred else None,
                }
            )
        return records

    def list_parent_children(self, *, parent: User, db: Session) -> dict:
        children = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.parent_id == parent.id,
                ChildProfile.deleted_at.is_(None),
            )
            .all()
        )
        progress = self._progress_by_child(
            db=db,
            child_ids=[child.id for child in children],
        )
        serialized = []
        for child in children:
            data = child_to_json(child)
            data.update(progress.get(child.id, {}))
            serialized.append(data)
        return {"children": serialized}

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
                # See create_child: age-only input is approximated to Jan 1 of
                # the birth year, since the UI never collects a real birth date.
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

        # Backfill the child's local-first progress on login. Child mode keeps
        # xp/level/streak/activities in local storage only, so on a fresh device
        # (or after the browser drops its storage) it would otherwise reset to
        # zero with no way to recover. We return the same all-time aggregate the
        # parent dashboard shows, computed from analytics, and the client merges
        # it into its local profile (taking the max, never regressing).
        progress = self._progress_by_child(db=db, child_ids=[child.id]).get(child.id, {})
        recent_activity = self._recent_activity_records(db=db, child_id=child.id)

        return {
            "success": True,
            "child_id": child.id,
            "name": child.name,
            "progress": progress,
            "recent_activity": recent_activity,
            "gamification_state": child.gamification_state,
            **session_payload,
        }

    def save_gamification_state(
        self,
        *,
        child_id: int,
        state: dict,
        db: Session,
        parent: User | None = None,
    ) -> dict:
        """Persist the child's local-first gamification snapshot (coins, badges,
        achievements, reward-store purchases) so it survives a fresh device /
        web storage reset. Last-write-wins: an older snapshot (by ``updated_at``)
        never clobbers a newer one already stored.

        When ``parent`` is supplied the child must belong to them, so a parent
        token can never write another family's child (mirrors the ownership
        guard the analytics ingest endpoints enforce).
        """
        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == child_id,
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if not child:
            raise not_found("Child not found")
        if parent is not None and int(child.parent_id) != int(parent.id):
            raise not_found("Child not found")

        incoming_updated = int((state or {}).get("updated_at") or 0)
        existing = child.gamification_state if isinstance(child.gamification_state, dict) else None
        existing_updated = int((existing or {}).get("updated_at") or 0)
        if existing is not None and incoming_updated < existing_updated:
            return {"success": True, "applied": False, "updated_at": existing_updated}

        child.gamification_state = state
        db.add(child)
        db.commit()
        return {"success": True, "applied": True, "updated_at": incoming_updated}

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

    # ── Child picture-password reset (parent-assisted via email link) ──────────

    def _picture_password_reset_expiry_minutes(self) -> int:
        return max(int(os.getenv("CHILD_PASSWORD_RESET_EXPIRES_MINUTES", "60")), 5)

    def _store_picture_password_reset_token(self, *, child: ChildProfile, token: str) -> None:
        now = db_utc_now()
        child.picture_password_reset_token_hash = hash_password(token)
        child.picture_password_reset_token_expires_at = now + timedelta(
            minutes=self._picture_password_reset_expiry_minutes()
        )
        child.updated_at = now

    @staticmethod
    def _clear_picture_password_reset_token(child: ChildProfile) -> None:
        child.picture_password_reset_token_hash = None
        child.picture_password_reset_token_expires_at = None

    def _picture_password_reset_token_expired(self, child: ChildProfile) -> bool:
        expires_at = getattr(child, "picture_password_reset_token_expires_at", None)
        return expires_at is None or ensure_utc(expires_at) <= utc_now()

    def _send_picture_password_reset_email(
        self,
        *,
        email: str,
        parent_name: str | None,
        child_name: str,
        token: str,
        app_base_url: str,
    ) -> None:
        reset_url = f"{app_base_url.rstrip('/')}/#/parent/reset-child-password?token={token}"
        greeting_name = (parent_name or "there").strip() or "there"
        safe_child = (child_name or "your child").strip() or "your child"
        expiry = self._picture_password_reset_expiry_minutes()
        subject = "Reset Your Child's Kinder World Picture Password"
        body = (
            f"Hello {greeting_name},\n\n"
            f"We received a request to reset the picture password for {safe_child}.\n"
            f"Click the link below to choose a new picture password:\n{reset_url}\n\n"
            f"This link expires in {expiry} minutes.\n"
            "If you did not request this, you can safely ignore this email.\n\n"
            "— The Kinder World Team"
        )
        html_body = f"""<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#f4f7fb;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0;">
    <tr><td align="center">
      <table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;padding:40px;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <tr><td align="center" style="padding-bottom:24px;">
          <h1 style="margin:0;font-size:26px;color:#1a3a6b;">Kinder World</h1>
        </td></tr>
        <tr><td style="font-size:16px;color:#333333;padding-bottom:16px;">
          Hello <strong>{greeting_name}</strong>,
        </td></tr>
        <tr><td style="font-size:16px;color:#333333;padding-bottom:24px;">
          We received a request to reset the picture password for <strong>{safe_child}</strong>. Click the button below to choose a new one:
        </td></tr>
        <tr><td align="center" style="padding-bottom:24px;">
          <a href="{reset_url}" style="display:inline-block;background:linear-gradient(135deg,#1a3a6b,#4a6cf7);color:#ffffff;text-decoration:none;border-radius:10px;padding:14px 36px;font-size:16px;font-weight:bold;">
            Reset Picture Password
          </a>
        </td></tr>
        <tr><td style="font-size:14px;color:#888888;padding-bottom:8px;">
          This link expires in <strong>{expiry} minutes</strong>.
        </td></tr>
        <tr><td style="font-size:13px;color:#aaaaaa;">
          If you did not request this, you can safely ignore this email.
        </td></tr>
        <tr><td style="padding-top:32px;font-size:13px;color:#aaaaaa;text-align:center;">
          The Kinder World Team
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""
        email_delivery_service.send_email(
            to_email=email, subject=subject, body=body, html_body=html_body
        )

    def request_picture_password_reset(
        self, *, payload: ChildForgotPasswordIn, db: Session
    ) -> dict:
        normalized_email = normalize_email(payload.parent_email)
        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == payload.child_id,
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )

        parent: User | None = None
        if child is not None:
            parent = db.query(User).filter(User.id == child.parent_id).first()

        # Anti-enumeration: always return the same generic success message. The
        # diagnostics below are server-side only and never leak to the response.
        if child is None:
            logger.info(
                "Child picture-password reset requested for child_id=%s but no profile exists; skipping send.",
                payload.child_id,
            )
        elif parent is None:
            logger.info(
                "Child picture-password reset requested for child_id=%s but parent is missing; skipping send.",
                payload.child_id,
            )
        elif (parent.email or "").strip().lower() != normalized_email:
            logger.info(
                "Child picture-password reset requested for child_id=%s but parent email did not match; skipping send.",
                payload.child_id,
            )
        elif not bool(getattr(parent, "email_verified", False)):
            logger.info(
                "Child picture-password reset requested for child_id=%s but parent email is not verified; skipping send.",
                payload.child_id,
            )

        if (
            child is not None
            and parent is not None
            and (parent.email or "").strip().lower() == normalized_email
            and bool(getattr(parent, "email_verified", False))
        ):
            token = secrets.token_urlsafe(32)
            self._store_picture_password_reset_token(child=child, token=token)
            db.add(child)
            db.commit()

            app_base_url = os.getenv("APP_BASE_URL", "http://localhost:44377")
            try:
                self._send_picture_password_reset_email(
                    email=parent.email,
                    parent_name=parent.name,
                    child_name=child.name,
                    token=token,
                    app_base_url=app_base_url,
                )
                logger.info(
                    "Child picture-password reset email dispatched for child_id=%s to %s.",
                    child.id,
                    parent.email,
                )
            except Exception as exc:
                logger.error(
                    "Failed to send child picture-password reset email for child_id=%s: %s",
                    child.id,
                    exc,
                    exc_info=True,
                )
                db.rollback()
                raise http_error(503, AuthMessages.CHILD_PASSWORD_RESET_SEND_FAILED)

        return {"success": True, "message": AuthMessages.CHILD_PASSWORD_RESET_EMAIL_SENT}

    def confirm_picture_password_reset(
        self, *, payload: ChildResetPicturePasswordIn, db: Session
    ) -> dict:
        validate_picture_password_length(payload.new_picture_password, length=3)

        candidates = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.picture_password_reset_token_hash.isnot(None),
                ChildProfile.deleted_at.is_(None),
            )
            .all()
        )
        matching_child: ChildProfile | None = None
        for candidate in candidates:
            token_hash = getattr(candidate, "picture_password_reset_token_hash", None)
            if token_hash and verify_password(payload.token, token_hash):
                matching_child = candidate
                break

        if matching_child is None or self._picture_password_reset_token_expired(matching_child):
            raise bad_request(AuthMessages.INVALID_OR_EXPIRED_CHILD_RESET_TOKEN)

        matching_child.picture_password = self._hash_picture_password(payload.new_picture_password)
        self._clear_picture_password_reset_token(matching_child)
        matching_child.updated_at = db_utc_now()
        db.add(matching_child)
        db.commit()

        return {"success": True, "message": AuthMessages.CHILD_PASSWORD_RESET_SUCCESSFUL}


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


def save_gamification_state(
    child_id: int, state: dict, db: Session, parent: User | None = None
) -> dict:
    return child_service.save_gamification_state(
        child_id=child_id, state=state, db=db, parent=parent
    )


def change_child_password(payload: ChildChangePasswordIn, db: Session) -> dict:
    return child_service.change_child_password(payload=payload, db=db)


def request_picture_password_reset(payload: ChildForgotPasswordIn, db: Session) -> dict:
    return child_service.request_picture_password_reset(payload=payload, db=db)


def confirm_picture_password_reset(payload: ChildResetPicturePasswordIn, db: Session) -> dict:
    return child_service.confirm_picture_password_reset(payload=payload, db=db)

"""Unit tests for services.child_service.ChildService.

Focuses on branches that are hard to reach end-to-end: the Redis-less
rate-limit / device-binding fallbacks, picture-password verification, profile
CRUD guard rails, child-session validation, and the module-level wrappers.

The autouse conftest fixtures mock Redis; several tests here monkeypatch
``get_redis_client`` to ``None`` to exercise the in-memory fallback paths.
"""

import pytest
from fastapi import HTTPException

import services.child_service as child_module
from auth import create_token
from models import ChildProfile
from schemas.auth import (
    ChildChangePasswordIn,
    ChildLoginIn,
    ChildRegisterIn,
    ChildSessionValidateIn,
)
from schemas.children import ChildCreate, ChildUpdate
from services.child_service import ChildService

PW = ["cat", "dog", "apple"]
PW2 = ["sun", "moon", "star"]


@pytest.fixture
def service():
    return ChildService()


def _make_child(service, db, parent, *, name="Kiddo", picture_password=None, age=7):
    payload = ChildCreate(
        name=name,
        picture_password=picture_password or PW,
        age=age,
        parent_email=parent.email,
    )
    service.create_child_profile(payload=payload, parent=parent, db=db)
    return db.query(ChildProfile).filter(ChildProfile.name == name).first()


# ---------------------------------------------------------------------------
# picture-password helpers
# ---------------------------------------------------------------------------


def test_picture_password_length_dict(service):
    assert service.picture_password_length({"length": 3}) == 3


def test_picture_password_length_non_dict(service):
    assert service.picture_password_length("legacy-string") == 0
    assert service.picture_password_length({"no_length": True}) == 0


def test_verify_picture_password_roundtrip(service):
    envelope = service._hash_picture_password(PW)
    assert service._verify_picture_password(stored_password=envelope, provided_password=PW) is True
    assert (
        service._verify_picture_password(stored_password=envelope, provided_password=PW2) is False
    )


def test_verify_picture_password_rejects_non_dict(service):
    assert (
        service._verify_picture_password(stored_password=["plain"], provided_password=PW) is False
    )


def test_ensure_parent_email_match_and_none(service, create_parent):
    parent = create_parent(email="match@example.com")
    # None short-circuits, exact match returns without raising.
    service._ensure_parent_matches_payload_email(parent=parent, parent_email=None)
    service._ensure_parent_matches_payload_email(parent=parent, parent_email="MATCH@example.com")


def test_ensure_parent_email_mismatch_forbidden(service, create_parent):
    parent = create_parent(email="real@example.com")
    with pytest.raises(HTTPException) as exc:
        service._ensure_parent_matches_payload_email(
            parent=parent, parent_email="other@example.com"
        )
    assert exc.value.status_code == 403


# ---------------------------------------------------------------------------
# create / list / update / delete profile
# ---------------------------------------------------------------------------


def test_create_child_profile_success(service, db, create_parent):
    parent = create_parent(email="cc-ok@example.com")
    result = service.create_child_profile(
        payload=ChildCreate(name="Adam", picture_password=PW, age=6, parent_email=parent.email),
        parent=parent,
        db=db,
    )
    assert result["child"]["name"] == "Adam"


def test_create_child_profile_duplicate_name(service, db, create_parent):
    from plan_service import PLAN_PREMIUM

    # Premium plan raises the child limit so the duplicate-name guard is reached
    # before the plan-limit guard.
    parent = create_parent(email="cc-dup@example.com", plan=PLAN_PREMIUM)
    _make_child(service, db, parent, name="Twin")
    with pytest.raises(HTTPException) as exc:
        service.create_child_profile(
            payload=ChildCreate(
                name="Twin", picture_password=PW2, age=6, parent_email=parent.email
            ),
            parent=parent,
            db=db,
        )
    assert exc.value.status_code == 400


def test_create_child_profile_limit_reached(service, db, create_parent):
    # FREE plan allows a single child; the second create hits the plan limit.
    parent = create_parent(email="cc-limit@example.com")
    _make_child(service, db, parent, name="First")
    with pytest.raises(HTTPException) as exc:
        service.create_child_profile(
            payload=ChildCreate(
                name="Second", picture_password=PW2, age=6, parent_email=parent.email
            ),
            parent=parent,
            db=db,
        )
    assert exc.value.status_code == 402


def test_list_parent_children(service, db, create_parent):
    parent = create_parent(email="cc-list@example.com")
    _make_child(service, db, parent, name="OnlyKid")
    result = service.list_parent_children(parent=parent, db=db)
    assert len(result["children"]) == 1


def test_list_parent_children_zero_progress_defaults(service, db, create_parent):
    # A child with no analytics yet still gets the progress keys, all zeroed
    # (level defaults to 1) so the parent card renders without errors.
    parent = create_parent(email="cc-progress-zero@example.com")
    _make_child(service, db, parent, name="FreshKid")
    item = service.list_parent_children(parent=parent, db=db)["children"][0]
    assert item["xp"] == 0
    assert item["level"] == 1
    assert item["streak"] == 0
    assert item["total_time_spent"] == 0
    assert item["activities_completed"] == 0


def test_list_parent_children_aggregates_progress(service, db, create_parent):
    from datetime import timedelta

    from core.time_utils import utc_now
    from models import ChildActivityEvent, ChildDailyActivitySummary, ChildSessionLog

    parent = create_parent(email="cc-progress@example.com")
    child = _make_child(service, db, parent, name="BusyKid")
    now = utc_now()
    today = now.date()

    # Two completed activities worth 600 + 700 XP → 1300 XP → level 2.
    db.add_all(
        [
            ChildActivityEvent(
                child_id=child.id,
                event_type="activity_completed",
                occurred_at=now,
                source="child_mode",
                points=600,
                duration_seconds=300,
            ),
            ChildActivityEvent(
                child_id=child.id,
                event_type="lesson_completed",
                occurred_at=now,
                source="child_mode",
                points=700,
                duration_seconds=300,
            ),
            # A non-completion event must not count toward activities or XP.
            ChildActivityEvent(
                child_id=child.id,
                event_type="mood_entry",
                occurred_at=now,
                source="child_mode",
                points=999,
                mood_value=5,
            ),
        ]
    )
    # 10 minutes of screen time from a session log.
    db.add(
        ChildSessionLog(
            child_id=child.id,
            session_id="s1",
            source="child_mode",
            started_at=now - timedelta(minutes=10),
            ended_at=now,
            duration_seconds=600,
        )
    )
    # Active today and yesterday → streak of 2.
    db.add_all(
        [
            ChildDailyActivitySummary(child_id=child.id, summary_date=today),
            ChildDailyActivitySummary(child_id=child.id, summary_date=today - timedelta(days=1)),
        ]
    )
    db.commit()

    item = service.list_parent_children(parent=parent, db=db)["children"][0]
    assert item["xp"] == 1300
    assert item["level"] == 2
    assert item["activities_completed"] == 2
    assert item["total_time_spent"] == 10
    assert item["streak"] == 2


def test_delete_child_profile_success(service, db, create_parent):
    parent = create_parent(email="cc-del@example.com")
    child = _make_child(service, db, parent, name="ToDelete")
    result = service.delete_child_profile(child_id=child.id, parent=parent, db=db)
    assert result["success"] is True


def test_delete_child_profile_not_found(service, db, create_parent):
    parent = create_parent(email="cc-del-404@example.com")
    with pytest.raises(HTTPException) as exc:
        service.delete_child_profile(child_id=999999, parent=parent, db=db)
    assert exc.value.status_code == 404


def test_delete_child_profile_forbidden(service, db, create_parent):
    owner = create_parent(email="cc-owner@example.com")
    intruder = create_parent(email="cc-intruder@example.com")
    child = _make_child(service, db, owner, name="NotYours")
    with pytest.raises(HTTPException) as exc:
        service.delete_child_profile(child_id=child.id, parent=intruder, db=db)
    assert exc.value.status_code == 403


def test_update_child_profile_all_fields(service, db, create_parent):
    parent = create_parent(email="cc-upd@example.com")
    child = _make_child(service, db, parent, name="Before")
    payload = ChildUpdate(
        name="After",
        picture_password=PW2,
        age=8,
        avatar="assets/images/avatars/av2.png",
    )
    result = service.update_child_profile(child_id=child.id, payload=payload, parent=parent, db=db)
    assert result["child"]["name"] == "After"


def test_update_child_profile_not_found(service, db, create_parent):
    parent = create_parent(email="cc-upd-404@example.com")
    with pytest.raises(HTTPException) as exc:
        service.update_child_profile(
            child_id=999999, payload=ChildUpdate(name="X"), parent=parent, db=db
        )
    assert exc.value.status_code == 404


def test_update_child_profile_forbidden(service, db, create_parent):
    owner = create_parent(email="cc-upd-owner@example.com")
    intruder = create_parent(email="cc-upd-intruder@example.com")
    child = _make_child(service, db, owner, name="Owned")
    with pytest.raises(HTTPException) as exc:
        service.update_child_profile(
            child_id=child.id, payload=ChildUpdate(name="Hijack"), parent=intruder, db=db
        )
    assert exc.value.status_code == 403


def test_register_child_delegates_to_create(service, db, create_parent):
    parent = create_parent(email="cc-reg@example.com")
    payload = ChildRegisterIn(
        name="Registered",
        picture_password=PW,
        age=5,
        parent_email=parent.email,
    )
    result = service.register_child(payload=payload, parent=parent, db=db)
    assert result["child"]["name"] == "Registered"


# ---------------------------------------------------------------------------
# login_child (happy + failure branches)
# ---------------------------------------------------------------------------


def test_login_child_success(service, db, create_parent):
    parent = create_parent(email="lc-ok@example.com")
    child = _make_child(service, db, parent, name="Lina")
    payload = ChildLoginIn(child_id=child.id, name="Lina", picture_password=PW)
    result = service.login_child(payload=payload, db=db, client_ip="1.2.3.4")
    assert result["success"] is True
    assert result["child_id"] == child.id
    assert "session_token" in result


def test_login_child_returns_recent_activity(service, db, create_parent):
    from datetime import timedelta

    from core.time_utils import utc_now
    from models import ChildActivityEvent

    parent = create_parent(email="lc-recent@example.com")
    child = _make_child(service, db, parent, name="Recent")
    now = utc_now()
    db.add_all(
        [
            # A game completion: the badge key lives in metadata_json.activity_id.
            ChildActivityEvent(
                child_id=child.id,
                event_type="activity_completed",
                occurred_at=now,
                source="child_mode",
                points=120,
                duration_seconds=300,
                activity_name="Memory Match",
                metadata_json={
                    "activity_id": "game_memory_1",
                    "client_record_id": "local-rec-1",
                },
            ),
            # An older lesson completion → still returned (all-time history, not
            # just today), so the "done" badge persists.
            ChildActivityEvent(
                child_id=child.id,
                event_type="lesson_completed",
                occurred_at=now - timedelta(days=5),
                source="child_mode",
                points=50,
                lesson_id="lesson_math_1",
                metadata_json={"activity_id": "lesson_math_1"},
            ),
            # Non-completion event → must be excluded.
            ChildActivityEvent(
                child_id=child.id,
                event_type="mood_entry",
                occurred_at=now,
                source="child_mode",
                mood_value=5,
            ),
        ]
    )
    db.commit()

    payload = ChildLoginIn(child_id=child.id, name="Recent", picture_password=PW)
    result = service.login_child(payload=payload, db=db, client_ip="1.2.3.4")

    recent = result["recent_activity"]
    assert len(recent) == 2  # both completions, mood entry excluded

    by_activity = {r["activity_id"]: r for r in recent}
    assert by_activity["game_memory_1"]["client_record_id"] == "local-rec-1"
    assert by_activity["game_memory_1"]["points"] == 120
    # The human-readable title rides along so the client history feed can show it
    # instead of the raw activity id when the activity isn't in the local catalog.
    assert by_activity["game_memory_1"]["activity_name"] == "Memory Match"
    assert "lesson_math_1" in by_activity  # all-time, not windowed


def test_save_and_login_returns_gamification_state(service, db, create_parent):
    parent = create_parent(email="lc-gam@example.com")
    child = _make_child(service, db, parent, name="Gamer")

    state = {
        "updated_at": 1750000000000,
        "data": {f"gam_coins_{child.id}": 120, f"store_owned_{child.id}": '["hat_1"]'},
    }
    res = service.save_gamification_state(child_id=child.id, state=state, db=db)
    assert res["applied"] is True

    payload = ChildLoginIn(child_id=child.id, name="Gamer", picture_password=PW)
    result = service.login_child(payload=payload, db=db, client_ip="1.2.3.4")
    assert result["gamification_state"]["data"][f"gam_coins_{child.id}"] == 120


def test_save_gamification_state_last_write_wins(service, db, create_parent):
    parent = create_parent(email="lc-gam-lww@example.com")
    child = _make_child(service, db, parent, name="Gamer2")

    newer = {"updated_at": 2000, "data": {"coins": 50}}
    older = {"updated_at": 1000, "data": {"coins": 5}}

    assert service.save_gamification_state(child_id=child.id, state=newer, db=db)["applied"] is True
    # An older snapshot must NOT clobber the newer one already stored.
    res = service.save_gamification_state(child_id=child.id, state=older, db=db)
    assert res["applied"] is False

    db.refresh(child)
    assert child.gamification_state["data"]["coins"] == 50


def test_login_child_not_found(service, db, create_parent):
    create_parent(email="lc-404@example.com")
    payload = ChildLoginIn(child_id=999999, name="Ghost", picture_password=PW)
    with pytest.raises(HTTPException) as exc:
        service.login_child(payload=payload, db=db)
    assert exc.value.status_code == 404


def test_login_child_invalid_name(service, db, create_parent):
    parent = create_parent(email="lc-name@example.com")
    child = _make_child(service, db, parent, name="Correct")
    payload = ChildLoginIn(child_id=child.id, name="Wrong", picture_password=PW)
    with pytest.raises(HTTPException) as exc:
        service.login_child(payload=payload, db=db)
    assert exc.value.status_code == 401


def test_login_child_invalid_picture_password(service, db, create_parent):
    parent = create_parent(email="lc-pw@example.com")
    child = _make_child(service, db, parent, name="Sara")
    payload = ChildLoginIn(child_id=child.id, name="Sara", picture_password=PW2)
    with pytest.raises(HTTPException) as exc:
        service.login_child(payload=payload, db=db)
    assert exc.value.status_code == 401


def test_login_child_rate_limited_in_memory(service, db, create_parent, monkeypatch):
    monkeypatch.setattr(child_module, "get_redis_client", lambda: None)
    child_module._FAILED_ATTEMPTS.clear()
    parent = create_parent(email="lc-rate@example.com")
    child = _make_child(service, db, parent, name="RateKid")
    bad = ChildLoginIn(child_id=child.id, name="WrongName", picture_password=PW)

    statuses = []
    for _ in range(7):
        try:
            service.login_child(payload=bad, db=db, client_ip="9.9.9.9")
        except HTTPException as exc:
            statuses.append(exc.status_code)
    assert 429 in statuses  # rate limit eventually trips


# ---------------------------------------------------------------------------
# device binding (Redis-less fallback)
# ---------------------------------------------------------------------------


def test_login_child_device_binding_mismatch(service, db, create_parent, monkeypatch):
    monkeypatch.setattr(child_module, "get_redis_client", lambda: None)
    monkeypatch.setenv("CHILD_AUTH_DEVICE_BINDING_ENABLED", "true")
    child_module._DEVICE_BINDINGS.clear()
    parent = create_parent(email="lc-dev@example.com")
    child = _make_child(service, db, parent, name="DevKid")

    first = ChildLoginIn(child_id=child.id, name="DevKid", picture_password=PW, device_id="dev-a")
    assert service.login_child(payload=first, db=db)["success"] is True

    second = ChildLoginIn(child_id=child.id, name="DevKid", picture_password=PW, device_id="dev-b")
    with pytest.raises(HTTPException) as exc:
        service.login_child(payload=second, db=db)
    assert exc.value.status_code == 403


def test_login_child_device_id_required(service, db, create_parent, monkeypatch):
    monkeypatch.setattr(child_module, "get_redis_client", lambda: None)
    monkeypatch.setenv("CHILD_AUTH_DEVICE_BINDING_ENABLED", "true")
    monkeypatch.setenv("CHILD_AUTH_REQUIRE_DEVICE_ID", "true")
    child_module._DEVICE_BINDINGS.clear()
    parent = create_parent(email="lc-devreq@example.com")
    child = _make_child(service, db, parent, name="ReqKid")

    payload = ChildLoginIn(child_id=child.id, name="ReqKid", picture_password=PW)
    with pytest.raises(HTTPException) as exc:
        service.login_child(payload=payload, db=db)
    assert exc.value.status_code == 422


# ---------------------------------------------------------------------------
# validate_child_session
# ---------------------------------------------------------------------------


def _child_session_token(child, *, device_id=None):
    extra = {"token_type": "child_session", "child_id": child.id, "child_name": child.name}
    if device_id:
        extra["device_id"] = device_id
    return create_token(str(child.id), minutes=60, extra_claims=extra)


def test_validate_child_session_success(service, db, create_parent):
    parent = create_parent(email="vs-ok@example.com")
    child = _make_child(service, db, parent, name="SessKid")
    token = _child_session_token(child)
    result = service.validate_child_session(
        payload=ChildSessionValidateIn(session_token=token), db=db
    )
    assert result["success"] is True
    assert result["child_id"] == child.id


def test_validate_child_session_invalid_token(service, db):
    with pytest.raises(HTTPException) as exc:
        service.validate_child_session(
            payload=ChildSessionValidateIn(session_token="garbage"), db=db
        )
    assert exc.value.status_code == 401


def test_validate_child_session_wrong_token_type(service, db, create_parent):
    parent = create_parent(email="vs-type@example.com")
    child = _make_child(service, db, parent, name="TypeKid")
    token = create_token(str(child.id), minutes=60, extra_claims={"token_type": "access"})
    with pytest.raises(HTTPException) as exc:
        service.validate_child_session(payload=ChildSessionValidateIn(session_token=token), db=db)
    assert exc.value.status_code == 401


def test_validate_child_session_child_not_found(service, db):
    token = create_token(
        "424242",
        minutes=60,
        extra_claims={"token_type": "child_session", "child_id": 424242},
    )
    with pytest.raises(HTTPException) as exc:
        service.validate_child_session(payload=ChildSessionValidateIn(session_token=token), db=db)
    assert exc.value.status_code == 404


def test_validate_child_session_device_required(service, db, create_parent):
    parent = create_parent(email="vs-devreq@example.com")
    child = _make_child(service, db, parent, name="VsDevKid")
    token = _child_session_token(child, device_id="dev-a")
    with pytest.raises(HTTPException) as exc:
        service.validate_child_session(
            payload=ChildSessionValidateIn(session_token=token), db=db  # no device_id
        )
    assert exc.value.status_code == 401


def test_validate_child_session_device_mismatch(service, db, create_parent):
    parent = create_parent(email="vs-devmis@example.com")
    child = _make_child(service, db, parent, name="VsMisKid")
    token = _child_session_token(child, device_id="dev-a")
    with pytest.raises(HTTPException) as exc:
        service.validate_child_session(
            payload=ChildSessionValidateIn(session_token=token, device_id="dev-b"), db=db
        )
    assert exc.value.status_code == 401


# ---------------------------------------------------------------------------
# change_child_password
# ---------------------------------------------------------------------------


def test_change_child_password_success(service, db, create_parent):
    parent = create_parent(email="ccp-ok@example.com")
    child = _make_child(service, db, parent, name="PwKid")
    payload = ChildChangePasswordIn(
        child_id=child.id,
        name="PwKid",
        current_picture_password=PW,
        new_picture_password=PW2,
    )
    result = service.change_child_password(payload=payload, db=db)
    assert result["success"] is True
    # The new password now verifies.
    login = ChildLoginIn(child_id=child.id, name="PwKid", picture_password=PW2)
    assert service.login_child(payload=login, db=db)["success"] is True


def test_change_child_password_not_found(service, db):
    payload = ChildChangePasswordIn(
        child_id=999999,
        name="Ghost",
        current_picture_password=PW,
        new_picture_password=PW2,
    )
    with pytest.raises(HTTPException) as exc:
        service.change_child_password(payload=payload, db=db)
    assert exc.value.status_code == 404


def test_change_child_password_invalid_name(service, db, create_parent):
    parent = create_parent(email="ccp-name@example.com")
    child = _make_child(service, db, parent, name="RealName")
    payload = ChildChangePasswordIn(
        child_id=child.id,
        name="WrongName",
        current_picture_password=PW,
        new_picture_password=PW2,
    )
    with pytest.raises(HTTPException) as exc:
        service.change_child_password(payload=payload, db=db)
    assert exc.value.status_code == 401


def test_change_child_password_wrong_current(service, db, create_parent):
    parent = create_parent(email="ccp-wrong@example.com")
    child = _make_child(service, db, parent, name="WrongCur")
    payload = ChildChangePasswordIn(
        child_id=child.id,
        name="WrongCur",
        current_picture_password=PW2,  # not the stored password
        new_picture_password=["a", "b", "c"],
    )
    with pytest.raises(HTTPException) as exc:
        service.change_child_password(payload=payload, db=db)
    assert exc.value.status_code == 401


# ---------------------------------------------------------------------------
# module-level wrappers
# ---------------------------------------------------------------------------


def test_module_wrappers_delegate(monkeypatch):
    calls = {}

    def stub(name):
        def _fn(**kwargs):
            calls[name] = kwargs
            return {"stub": name}

        return _fn

    for name in (
        "enforce_child_limit",
        "ensure_unique_child_name",
        "create_child_profile",
        "list_parent_children",
        "delete_child_profile",
        "update_child_profile",
        "register_child",
        "login_child",
        "validate_child_session",
        "change_child_password",
    ):
        monkeypatch.setattr(child_module.child_service, name, stub(name))

    assert child_module.enforce_child_limit("p", "db") == {"stub": "enforce_child_limit"}
    assert (
        child_module.ensure_unique_child_name("p", "n", "db")["stub"] == "ensure_unique_child_name"
    )
    assert child_module.create_child_profile("pl", "p", "db")["stub"] == "create_child_profile"
    assert child_module.list_parent_children("p", "db")["stub"] == "list_parent_children"
    assert child_module.delete_child_profile(1, "p", "db")["stub"] == "delete_child_profile"
    assert child_module.update_child_profile(1, "pl", "p", "db")["stub"] == "update_child_profile"
    assert child_module.register_child("pl", "p", "db")["stub"] == "register_child"
    assert child_module.login_child("pl", "db")["stub"] == "login_child"
    assert child_module.validate_child_session("pl", "db")["stub"] == "validate_child_session"
    assert child_module.change_child_password("pl", "db")["stub"] == "change_child_password"

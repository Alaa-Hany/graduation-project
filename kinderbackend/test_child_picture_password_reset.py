"""Tests for the parent-assisted child picture-password reset flow.

Covers request_picture_password_reset (token issuance + anti-enumeration) and
confirm_picture_password_reset (token verification + password rotation).
"""

import pytest
from fastapi import HTTPException

from models import ChildProfile
from schemas.auth import ChildForgotPasswordIn, ChildResetPicturePasswordIn
from schemas.children import ChildCreate
from services.child_service import ChildService

PW = ["cat", "dog", "apple"]
PW2 = ["sun", "moon", "star"]


@pytest.fixture
def service():
    return ChildService()


def _make_child(service, db, parent, *, name="Kiddo"):
    payload = ChildCreate(name=name, picture_password=PW, age=7, parent_email=parent.email)
    service.create_child_profile(payload=payload, parent=parent, db=db)
    return db.query(ChildProfile).filter(ChildProfile.name == name).first()


def test_request_issues_token_for_matching_parent(service, db, create_parent):
    parent = create_parent(email="reset-ok@example.com")
    child = _make_child(service, db, parent)

    result = service.request_picture_password_reset(
        payload=ChildForgotPasswordIn(child_id=child.id, parent_email=parent.email),
        db=db,
    )
    assert result["success"] is True

    db.refresh(child)
    assert child.picture_password_reset_token_hash is not None
    assert child.picture_password_reset_token_expires_at is not None


def test_request_does_not_issue_token_on_email_mismatch(service, db, create_parent):
    parent = create_parent(email="reset-real@example.com")
    child = _make_child(service, db, parent)

    # Same generic success, but no token stored (anti-enumeration).
    result = service.request_picture_password_reset(
        payload=ChildForgotPasswordIn(child_id=child.id, parent_email="wrong@example.com"),
        db=db,
    )
    assert result["success"] is True

    db.refresh(child)
    assert child.picture_password_reset_token_hash is None


def test_request_unknown_child_returns_generic_success(service, db, create_parent):
    create_parent(email="reset-none@example.com")
    result = service.request_picture_password_reset(
        payload=ChildForgotPasswordIn(child_id=999999, parent_email="reset-none@example.com"),
        db=db,
    )
    assert result["success"] is True


def test_confirm_resets_password_with_valid_token(service, db, create_parent, monkeypatch):
    parent = create_parent(email="reset-confirm@example.com")
    child = _make_child(service, db, parent)

    # Capture the plaintext token from the email-send call (the stored value is
    # only a hash, so this is the only place the raw token is visible).
    captured = {}
    monkeypatch.setattr(
        service,
        "_send_picture_password_reset_email",
        lambda **kw: captured.update(token=kw["token"]),
    )

    service.request_picture_password_reset(
        payload=ChildForgotPasswordIn(child_id=child.id, parent_email=parent.email),
        db=db,
    )
    token = captured["token"]

    # Old password works before reset.
    db.refresh(child)
    assert service._verify_picture_password(
        stored_password=child.picture_password, provided_password=PW
    )

    result = service.confirm_picture_password_reset(
        payload=ChildResetPicturePasswordIn(token=token, new_picture_password=PW2),
        db=db,
    )
    assert result["success"] is True

    db.refresh(child)
    # New password works, old does not, token cleared.
    assert service._verify_picture_password(
        stored_password=child.picture_password, provided_password=PW2
    )
    assert not service._verify_picture_password(
        stored_password=child.picture_password, provided_password=PW
    )
    assert child.picture_password_reset_token_hash is None


def test_confirm_rejects_invalid_token(service, db, create_parent):
    parent = create_parent(email="reset-bad@example.com")
    _make_child(service, db, parent)

    with pytest.raises(HTTPException) as exc:
        service.confirm_picture_password_reset(
            payload=ChildResetPicturePasswordIn(
                token="definitely-not-a-real-token", new_picture_password=PW2
            ),
            db=db,
        )
    assert exc.value.status_code == 400


# ---------------------------------------------------------------------------
# "{child_id}:{secret}" token design (O(1) lookup, SHA-256 of the secret)
# ---------------------------------------------------------------------------


def _issue_token(service, db, child) -> str:
    token = service._issue_picture_password_reset_token(child=child)
    db.add(child)
    db.commit()
    return token


def _confirm(service, db, token, new_password=PW2):
    return service.confirm_picture_password_reset(
        payload=ChildResetPicturePasswordIn(token=token, new_picture_password=new_password),
        db=db,
    )


def test_token_is_child_id_prefixed_and_stores_sha256_of_secret(service, db, create_parent):
    parent = create_parent(email="reset-shape-child@example.com")
    child = _make_child(service, db, parent)

    token = _issue_token(service, db, child)

    child_id, _, secret = token.partition(":")
    assert child_id == str(child.id)
    assert len(secret) >= 40
    db.refresh(child)
    assert child.picture_password_reset_token_hash == (
        service._hash_picture_password_reset_secret(secret)
    )


def test_confirm_never_runs_bcrypt_on_tokens(service, db, create_parent, monkeypatch):
    # Regression: confirmation used to bcrypt-verify the token against every
    # child with a pending reset (O(n) bcrypt per request, an easy CPU DoS).
    import services.child_service as child_module

    # One child per parent: the free plan allows a single child.
    children = [
        _make_child(
            service, db, create_parent(email=f"reset-many-child{i}@example.com"), name=f"Kid{i}"
        )
        for i in range(4)
    ]
    tokens = [_issue_token(service, db, c) for c in children]

    def _no_bcrypt(*args, **kwargs):
        raise AssertionError("reset confirmation must not call bcrypt verify")

    monkeypatch.setattr(child_module, "verify_password", _no_bcrypt)

    for bad in ("garbage", f"{children[0].id}:wrong-secret", "999999:whatever"):
        with pytest.raises(HTTPException) as exc:
            _confirm(service, db, bad)
        assert exc.value.status_code == 400

    assert _confirm(service, db, tokens[2])["success"] is True


def test_confirm_rejects_token_secret_for_another_child(service, db, create_parent):
    first = _make_child(
        service, db, create_parent(email="reset-swap-child1@example.com"), name="First"
    )
    second = _make_child(
        service, db, create_parent(email="reset-swap-child2@example.com"), name="Second"
    )
    first_token = _issue_token(service, db, first)
    _issue_token(service, db, second)
    _, _, first_secret = first_token.partition(":")

    with pytest.raises(HTTPException) as exc:
        _confirm(service, db, f"{second.id}:{first_secret}")
    assert exc.value.status_code == 400


def test_confirm_token_is_single_use(service, db, create_parent):
    parent = create_parent(email="reset-once-child@example.com")
    child = _make_child(service, db, parent)
    token = _issue_token(service, db, child)

    assert _confirm(service, db, token)["success"] is True
    with pytest.raises(HTTPException) as exc:
        _confirm(service, db, token, new_password=PW)
    assert exc.value.status_code == 400


def test_confirm_rejects_expired_token(service, db, create_parent):
    from datetime import timedelta

    from core.time_utils import db_utc_now

    parent = create_parent(email="reset-expired-child@example.com")
    child = _make_child(service, db, parent)
    token = _issue_token(service, db, child)
    child.picture_password_reset_token_expires_at = db_utc_now() - timedelta(minutes=1)
    db.add(child)
    db.commit()

    with pytest.raises(HTTPException) as exc:
        _confirm(service, db, token)
    assert exc.value.status_code == 400


def test_confirm_rejects_token_for_deleted_child(service, db, create_parent):
    from core.time_utils import db_utc_now

    parent = create_parent(email="reset-deleted-child@example.com")
    child = _make_child(service, db, parent)
    token = _issue_token(service, db, child)
    child.deleted_at = db_utc_now()
    db.add(child)
    db.commit()

    with pytest.raises(HTTPException) as exc:
        _confirm(service, db, token)
    assert exc.value.status_code == 400


def test_confirm_old_format_token_fails_safely(service, db, create_parent):
    # Links issued before the "{child_id}:{secret}" format stored a bcrypt hash
    # of a raw token. They must be rejected cleanly and change nothing.
    from datetime import timedelta

    from auth import hash_password
    from core.message_catalog import AuthMessages
    from core.time_utils import db_utc_now

    parent = create_parent(email="reset-legacy-child@example.com")
    child = _make_child(service, db, parent)
    child.picture_password_reset_token_hash = hash_password("legacy-raw-token")
    child.picture_password_reset_token_expires_at = db_utc_now() + timedelta(minutes=10)
    db.add(child)
    db.commit()

    for legacy in ("legacy-raw-token", f"{child.id}:legacy-raw-token"):
        with pytest.raises(HTTPException) as exc:
            _confirm(service, db, legacy)
        assert exc.value.status_code == 400
        assert exc.value.detail == AuthMessages.INVALID_OR_EXPIRED_CHILD_RESET_TOKEN

    db.refresh(child)
    assert service._verify_picture_password(
        stored_password=child.picture_password, provided_password=PW
    )

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

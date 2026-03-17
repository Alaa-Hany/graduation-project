"""
Test change password endpoint with camelCase and snake_case compatibility.
Also tests plan gating for basic features.

Run with: pytest test_change_password_compat.py -v
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from auth import create_access_token, hash_password, verify_password
from models import User


@pytest.fixture
def test_user(db: Session):
    """Create a test user."""
    user = User(
        email="test@example.com",
        password_hash=hash_password("CurrentPass123!"),
        name="Test User",
        plan="FREE",
        role="parent",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def test_user_token(test_user: User):
    """Create access token for test user."""
    return create_access_token(str(test_user.id))


# ============================================================================
# CHANGE PASSWORD TESTS: camelCase vs snake_case
# ============================================================================


class TestChangePasswordCamelCase:
    """Test change password with camelCase (web client style)."""

    def test_change_password_camelcase_success(
        self, client: TestClient, test_user: User, test_user_token: str, db: Session
    ):
        """Success with camelCase fields (currentPassword, newPassword, confirmPassword)."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "Password changed successfully" in data["message"]

        # Verify password actually changed in DB
        db.refresh(test_user)
        assert verify_password("NewPass456!", test_user.password_hash)
        assert not verify_password("CurrentPass123!", test_user.password_hash)


class TestChangePasswordSnakeCase:
    """Test change password with snake_case (mobile client style)."""

    def test_change_password_snake_case_success(
        self, client: TestClient, test_user: User, test_user_token: str, db: Session
    ):
        """Success with snake_case fields (current_password, new_password, confirm_password)."""
        response = client.post(
            "/auth/change-password",
            json={
                "current_password": "CurrentPass123!",
                "new_password": "NewPass456!",
                "confirm_password": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "Password changed successfully" in data["message"]

        # Verify password actually changed in DB
        db.refresh(test_user)
        assert verify_password("NewPass456!", test_user.password_hash)
        assert not verify_password("CurrentPass123!", test_user.password_hash)

    def test_change_password_mixed_case_success(
        self, client: TestClient, test_user: User, test_user_token: str, db: Session
    ):
        """Success with MIXED camelCase and snake_case (client inconsistency)."""
        response = client.post(
            "/auth/change-password",
            json={
                "current_password": "CurrentPass123!",  # snake_case
                "newPassword": "NewPass456!",  # camelCase
                "confirm_password": "NewPass456!",  # snake_case
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True


class TestChangePasswordErrors:
    """Test error handling."""

    def test_wrong_current_password_camelcase(self, client: TestClient, test_user_token: str):
        """401 when current password wrong (camelCase)."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "WrongPassword123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 401
        assert "Current password is incorrect" in response.json()["detail"]

    def test_wrong_current_password_snake_case(self, client: TestClient, test_user_token: str):
        """401 when current password wrong (snake_case)."""
        response = client.post(
            "/auth/change-password",
            json={
                "current_password": "WrongPassword123!",
                "new_password": "NewPass456!",
                "confirm_password": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 401
        assert "Current password is incorrect" in response.json()["detail"]

    def test_password_mismatch_camelcase(self, client: TestClient, test_user_token: str):
        """400 when new password doesn't match confirm (camelCase)."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "DifferentPass789!",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 400
        assert "do not match" in response.json()["detail"]

    def test_password_mismatch_snake_case(self, client: TestClient, test_user_token: str):
        """400 when new password doesn't match confirm (snake_case)."""
        response = client.post(
            "/auth/change-password",
            json={
                "current_password": "CurrentPass123!",
                "new_password": "NewPass456!",
                "confirm_password": "DifferentPass789!",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 400
        assert "do not match" in response.json()["detail"]

    def test_weak_password_camelcase(self, client: TestClient, test_user_token: str):
        """422 when password too weak (camelCase)."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "weak",  # Too short, no uppercase, no special
                "confirmPassword": "weak",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert isinstance(detail, str)
        assert "at least 8 characters" in detail

    def test_weak_password_snake_case(self, client: TestClient, test_user_token: str):
        """422 when password too weak (snake_case)."""
        response = client.post(
            "/auth/change-password",
            json={
                "current_password": "CurrentPass123!",
                "new_password": "weak",  # Too short, no uppercase, no special
                "confirm_password": "weak",
            },
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert isinstance(detail, str)
        assert "at least 8 characters" in detail


# ============================================================================
# PLAN GATING TESTS: Basic features for FREE users
# ============================================================================


class TestBasicFeaturePlans:
    """Test that basic features are accessible to FREE users."""

    def test_free_user_can_access_basic_reports(self, client: TestClient, test_user_token: str):
        """FREE user CAN access /reports/basic."""
        response = client.get(
            "/reports/basic", headers={"Authorization": f"Bearer {test_user_token}"}
        )
        assert response.status_code == 200

    def test_free_user_can_access_basic_notifications(
        self, client: TestClient, test_user_token: str
    ):
        """FREE user CAN access /notifications/basic."""
        response = client.get(
            "/notifications/basic", headers={"Authorization": f"Bearer {test_user_token}"}
        )
        assert response.status_code == 200

    def test_free_user_can_access_basic_parental_controls(
        self, client: TestClient, test_user_token: str
    ):
        """FREE user CAN access /parental-controls/basic."""
        response = client.get(
            "/parental-controls/basic", headers={"Authorization": f"Bearer {test_user_token}"}
        )
        assert response.status_code == 200

    def test_free_user_cannot_access_advanced_reports(
        self, client: TestClient, test_user_token: str
    ):
        """FREE user CANNOT access /reports/advanced (403)."""
        response = client.get(
            "/reports/advanced", headers={"Authorization": f"Bearer {test_user_token}"}
        )
        assert response.status_code == 403
        assert "FEATURE_NOT_AVAILABLE" in response.json()["detail"]["code"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

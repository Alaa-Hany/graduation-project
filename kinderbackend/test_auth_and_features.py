"""
test_auth_and_features.py
Comprehensive test suite for change password endpoint and feature gating.

Run with: pytest test_auth_and_features.py -v
"""

import pytest
from sqlalchemy.orm import Session

from auth import create_access_token, hash_password, verify_password
from models import User
from plan_service import PLAN_FAMILY_PLUS, PLAN_FREE, PLAN_PREMIUM


# Test User Fixtures
@pytest.fixture
def free_user(db: Session):
    """Create a FREE plan user."""
    user = User(
        email="free@example.com",
        password_hash=hash_password("CurrentPass123!"),
        name="Free User",
        plan=PLAN_FREE,
        role="parent",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def premium_user(db: Session):
    """Create a PREMIUM plan user."""
    user = User(
        email="premium@example.com",
        password_hash=hash_password("CurrentPass123!"),
        name="Premium User",
        plan=PLAN_PREMIUM,
        role="parent",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def family_plus_user(db: Session):
    """Create a FAMILY_PLUS plan user."""
    user = User(
        email="familyplus@example.com",
        password_hash=hash_password("CurrentPass123!"),
        name="Family Plus User",
        plan=PLAN_FAMILY_PLUS,
        role="parent",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def free_user_token(free_user):
    """Create access token for free user."""
    return create_access_token(str(free_user.id))


@pytest.fixture
def premium_user_token(premium_user):
    """Create access token for premium user."""
    return create_access_token(str(premium_user.id))


@pytest.fixture
def family_plus_user_token(family_plus_user):
    """Create access token for family plus user."""
    return create_access_token(str(family_plus_user.id))


# ============================================================================
# CHANGE PASSWORD ENDPOINT TESTS
# ============================================================================


class TestChangePasswordSuccess:
    """Test successful password change scenarios."""

    def test_change_password_valid(
        self, client, free_user: User, free_user_token: str, db: Session
    ):
        """Test successful password change with valid credentials."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "Password changed successfully" in data["message"]

        # Verify password actually changed in DB
        db.refresh(free_user)
        assert verify_password("NewPass456!", free_user.password_hash)
        assert not verify_password("CurrentPass123!", free_user.password_hash)

    def test_change_password_with_complex_characters(
        self, client, free_user: User, free_user_token: str, db: Session
    ):
        """Test password change with complex special characters."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "C0mpl3x@P#ssw0rd",
                "confirmPassword": "C0mpl3x@P#ssw0rd",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 200
        db.refresh(free_user)
        assert verify_password("C0mpl3x@P#ssw0rd", free_user.password_hash)


class TestChangePasswordValidation:
    """Test password validation rules."""

    def test_change_password_too_short(self, client, free_user_token: str):
        """Test rejection of too-short password (< 8 chars)."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "Short1!",  # 7 chars
                "confirmPassword": "Short1!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 422
        assert "at least 8 characters" in response.json()["detail"]

    def test_change_password_no_uppercase(self, client, free_user_token: str):
        """Test rejection of password without uppercase letter."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "noupppercase123!",
                "confirmPassword": "noupppercase123!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 422
        assert "uppercase letter" in response.json()["detail"]

    def test_change_password_no_digit(self, client, free_user_token: str):
        """Test rejection of password without digit."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NoDigitPass!",
                "confirmPassword": "NoDigitPass!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 422
        assert "digit" in response.json()["detail"]

    def test_change_password_no_special_char(self, client, free_user_token: str):
        """Test rejection of password without special character."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NoSpecial123",
                "confirmPassword": "NoSpecial123",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 422
        assert "special character" in response.json()["detail"]


class TestChangePasswordErrors:
    """Test error handling in change password endpoint."""

    def test_change_password_wrong_current(self, client, free_user_token: str):
        """Test with incorrect current password."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "WrongPassword123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 401
        assert "Current password is incorrect" in response.json()["detail"]

    def test_change_password_mismatch(self, client, free_user_token: str):
        """Test password confirmation mismatch."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "DifferentPass789!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )

        assert response.status_code == 400
        assert "do not match" in response.json()["detail"]

    def test_change_password_missing_token(self, client):
        """Test without authentication token."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
        )

        assert response.status_code == 401

    def test_change_password_invalid_token(self, client):
        """Test with invalid token."""
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
            headers={"Authorization": "Bearer invalid_token_xyz"},
        )

        assert response.status_code == 401


# ============================================================================
# FEATURE GATING TESTS - FREE USER
# ============================================================================


class TestFreeUserFeatures:
    """Test feature access for FREE plan users."""

    def test_free_user_can_access_basic_reports(self, client, free_user_token: str):
        """FREE user CAN access basic_reports."""
        response = client.get(
            "/reports/basic", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 200
        assert response.json()["access_level"] == "basic"

    def test_free_user_can_access_basic_notifications(self, client, free_user_token: str):
        """FREE user CAN access basic_notifications."""
        response = client.get(
            "/notifications/basic", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 200
        assert response.json()["access_level"] == "basic"

    def test_free_user_can_access_basic_parental_controls(self, client, free_user_token: str):
        """FREE user CAN access basic_parental_controls."""
        response = client.get(
            "/parental-controls/basic", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 200
        assert response.json()["access_level"] == "basic"

    def test_free_user_cannot_access_advanced_reports(self, client, free_user_token: str):
        """FREE user CANNOT access advanced_reports."""
        response = client.get(
            "/reports/advanced", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 403
        assert response.json()["detail"]["code"] == "FEATURE_NOT_AVAILABLE"

    def test_free_user_cannot_access_smart_notifications(self, client, free_user_token: str):
        """FREE user CANNOT access smart_notifications."""
        response = client.get(
            "/notifications/smart", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 403

    def test_free_user_cannot_access_ai_insights(self, client, free_user_token: str):
        """FREE user CANNOT access ai_insights."""
        response = client.get(
            "/ai/insights", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 403

    def test_free_user_cannot_access_offline_downloads(self, client, free_user_token: str):
        """FREE user CANNOT access offline_downloads."""
        response = client.get(
            "/downloads/offline", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 403

    def test_free_user_cannot_access_priority_support(self, client, free_user_token: str):
        """FREE user CANNOT access priority_support."""
        response = client.get(
            "/support/priority", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert response.status_code == 403


# ============================================================================
# FEATURE GATING TESTS - PREMIUM USER
# ============================================================================


class TestPremiumUserFeatures:
    """Test feature access for PREMIUM plan users."""

    def test_premium_inherits_free_features(self, client, premium_user_token: str):
        """PREMIUM user inherits all FREE tier features."""
        # Basic reports
        response = client.get(
            "/reports/basic", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 200

        # Basic notifications
        response = client.get(
            "/notifications/basic", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 200

        # Basic parental controls
        response = client.get(
            "/parental-controls/basic", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 200

    def test_premium_user_can_access_advanced_reports(self, client, premium_user_token: str):
        """PREMIUM user CAN access advanced_reports."""
        response = client.get(
            "/reports/advanced", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 200
        assert response.json()["access_level"] == "advanced"

    def test_premium_user_can_access_smart_notifications(self, client, premium_user_token: str):
        """PREMIUM user CAN access smart_notifications."""
        response = client.get(
            "/notifications/smart", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 200
        assert response.json()["access_level"] == "smart"

    def test_premium_user_can_access_ai_insights(self, client, premium_user_token: str):
        """PREMIUM user CAN access ai_insights."""
        response = client.get(
            "/ai/insights", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 200

    def test_premium_user_can_access_offline_downloads(self, client, premium_user_token: str):
        """PREMIUM user CAN access offline_downloads."""
        response = client.get(
            "/downloads/offline", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 200

    def test_premium_user_cannot_access_priority_support(self, client, premium_user_token: str):
        """PREMIUM user CANNOT access priority_support (FAMILY_PLUS only)."""
        response = client.get(
            "/support/priority", headers={"Authorization": f"Bearer {premium_user_token}"}
        )
        assert response.status_code == 403


# ============================================================================
# FEATURE GATING TESTS - FAMILY PLUS USER
# ============================================================================


class TestFamilyPlusUserFeatures:
    """Test feature access for FAMILY_PLUS plan users."""

    def test_family_plus_has_all_features(self, client, family_plus_user_token: str):
        """FAMILY_PLUS user has access to ALL features."""
        endpoints = [
            "/reports/basic",
            "/reports/advanced",
            "/notifications/basic",
            "/notifications/smart",
            "/parental-controls/basic",
            "/parental-controls/advanced",
            "/ai/insights",
            "/downloads/offline",
            "/support/priority",
        ]

        for endpoint in endpoints:
            response = client.get(
                endpoint, headers={"Authorization": f"Bearer {family_plus_user_token}"}
            )
            assert (
                response.status_code == 200
            ), f"Endpoint {endpoint} should be accessible for FAMILY_PLUS"


# ============================================================================
# INTEGRATION TESTS
# ============================================================================


class TestIntegration:
    """Integration tests combining password change and feature access."""

    def test_user_can_change_password_and_access_features_with_new_token(
        self, client, free_user: User, free_user_token: str, db: Session
    ):
        """User can change password and still access their features."""
        # Change password
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )
        assert response.status_code == 200

        # Old token should be revoked after password change.
        revoked = client.get(
            "/reports/basic", headers={"Authorization": f"Bearer {free_user_token}"}
        )
        assert revoked.status_code == 401

        login = client.post(
            "/auth/login",
            json={
                "email": free_user.email,
                "password": "NewPass456!",
            },
        )
        assert login.status_code == 200

        response = client.get(
            "/reports/basic",
            headers={"Authorization": f"Bearer {login.json()['access_token']}"},
        )
        assert response.status_code == 200

    def test_invalid_password_prevents_feature_access(self, client, free_user_token: str):
        """Invalid token prevents all feature access."""
        response = client.get("/reports/basic", headers={"Authorization": "Bearer invalid"})
        assert response.status_code == 401


# ============================================================================
# DATABASE PERSISTENCE TESTS
# ============================================================================


class TestDatabasePersistence:
    """Test that changes persist correctly in database."""

    def test_password_hash_persists_in_database(
        self, client, free_user: User, free_user_token: str, db: Session
    ):
        """Verify password hash is actually stored in database."""
        # Change password
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": "CurrentPass123!",
                "newPassword": "NewPass456!",
                "confirmPassword": "NewPass456!",
            },
            headers={"Authorization": f"Bearer {free_user_token}"},
        )
        assert response.status_code == 200

        # Query user from database
        db.refresh(free_user)
        stored_hash = free_user.password_hash

        # Verify hash is valid and matches new password
        assert verify_password("NewPass456!", stored_hash)
        assert not verify_password("CurrentPass123!", stored_hash)

        # Verify old password doesn't work
        old_password_works = verify_password("CurrentPass123!", stored_hash)
        assert not old_password_works


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])

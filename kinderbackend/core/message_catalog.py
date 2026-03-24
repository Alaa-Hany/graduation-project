from __future__ import annotations


class AuthMessages:
    AUTHENTICATION_REQUIRED = "Authentication required"
    INVALID_TOKEN = "Invalid token"
    INVALID_TOKEN_TYPE = "Invalid token type"
    INVALID_TOKEN_PAYLOAD = "Invalid token payload"
    TOKEN_REVOKED = "Token has been revoked"
    USER_NOT_FOUND = "User not found"
    INVALID_REFRESH_TOKEN = "Invalid refresh token"
    INVALID_CREDENTIALS = "Invalid credentials"
    PARENT_AUTH_TEMP_LOCKED = "Too many failed login attempts. Try again later."
    PASSWORDS_DO_NOT_MATCH = "Passwords do not match"
    EMAIL_ALREADY_REGISTERED = "Email already registered"
    FAILED_UPDATE_PROFILE = "Failed to update profile"
    CURRENT_PASSWORD_IS_INCORRECT = "Current password is incorrect"
    NEW_PASSWORD_CONFIRMATION_DOES_NOT_MATCH = "New password and confirmation do not match"
    PASSWORD_CHANGED_SUCCESSFULLY = "Password changed successfully"
    FAILED_CHANGE_PASSWORD = "Failed to change password. Please try again later."
    FAILED_LOGOUT = "Failed to logout"
    PARENT_PIN_ALREADY_EXISTS = "Parent PIN already exists. Use change PIN instead."
    PIN_CONFIRMATION_DOES_NOT_MATCH = "PIN confirmation does not match"
    PARENT_PIN_CREATED_SUCCESSFULLY = "Parent PIN created successfully"
    FAILED_SET_PARENT_PIN = "Failed to set parent PIN"
    PARENT_PIN_NOT_CONFIGURED = "Parent PIN is not configured"
    PARENT_PIN_TEMPORARILY_LOCKED = "Parent PIN is temporarily locked"
    PARENT_PIN_TOO_MANY_INVALID_ATTEMPTS = "Too many invalid PIN attempts"
    INCORRECT_PIN = "Incorrect PIN"
    FAILED_VERIFY_PARENT_PIN = "Failed to verify parent PIN"
    NEW_PIN_MUST_BE_DIFFERENT = "New PIN must be different"
    CURRENT_PIN_IS_INCORRECT = "Current PIN is incorrect"
    PARENT_PIN_CHANGED_SUCCESSFULLY = "Parent PIN changed successfully"
    FAILED_CHANGE_PARENT_PIN = "Failed to change parent PIN"
    PARENT_PIN_RESET_REQUEST_SUBJECT = "Parent PIN reset request"
    PARENT_PIN_RESET_REQUEST_MESSAGE = "Parent PIN reset requested."
    PARENT_PIN_RESET_REQUEST_CREATED = "Support request created for Parent PIN reset"
    FAILED_REQUEST_PIN_RESET = "Failed to request PIN reset"
    TWO_FACTOR_REQUIRED = "Two-factor authentication code is required"
    INVALID_TWO_FACTOR_CODE = "Invalid two-factor authentication code"
    TWO_FACTOR_ALREADY_ENABLED = "Two-factor authentication is already enabled"
    TWO_FACTOR_SETUP_REQUIRED = "Two-factor authentication setup is required before enabling it"
    TWO_FACTOR_ENABLED_SUCCESSFULLY = "Two-factor authentication enabled successfully"
    TWO_FACTOR_DISABLED_SUCCESSFULLY = "Two-factor authentication disabled successfully"


class AdminAuthMessages:
    AUTHENTICATION_REQUIRED = "Admin authentication required"
    INVALID_OR_EXPIRED_ADMIN_TOKEN = "Invalid or expired admin token"
    INVALID_ADMIN_TOKEN_TYPE = "Invalid admin token type"
    INVALID_ADMIN_TOKEN_PAYLOAD = "Invalid token payload"
    ADMIN_ACCOUNT_NOT_FOUND = "Admin account not found"
    ADMIN_TOKEN_REVOKED = "Admin token has been revoked"
    ADMIN_TEMP_LOCKED = "Too many failed login attempts. Try again later."
    INVALID_EMAIL_OR_PASSWORD = "Invalid email or password"
    ADMIN_DISABLED = "This admin account has been disabled"
    ADMIN_DISABLED_CONTACT_SUPER_ADMIN = (
        "This admin account has been disabled. Contact a super admin."
    )
    INVALID_OR_EXPIRED_REFRESH_TOKEN = "Invalid or expired refresh token"
    INVALID_REFRESH_TOKEN_TYPE = "Invalid refresh token type"
    INVALID_REFRESH_TOKEN_PAYLOAD = "Invalid refresh token payload"
    REFRESH_TOKEN_REVOKED = "Refresh token has been revoked"
    LOGGED_OUT_SUCCESSFULLY = "Logged out successfully"
    TWO_FACTOR_REQUIRED = "Two-factor authentication code is required"
    INVALID_TWO_FACTOR_CODE = "Invalid two-factor authentication code"
    TWO_FACTOR_ALREADY_ENABLED = "Two-factor authentication is already enabled"
    TWO_FACTOR_SETUP_REQUIRED = "Two-factor authentication setup is required before enabling it"
    TWO_FACTOR_ENABLED_SUCCESSFULLY = "Two-factor authentication enabled successfully"
    TWO_FACTOR_DISABLED_SUCCESSFULLY = "Two-factor authentication disabled successfully"


class SubscriptionMessages:
    INVALID_PLAN = "Invalid plan"
    PLAN_ID_OR_TYPE_REQUIRED = "plan_id or plan_type is required"
    PENDING_PLAN_SELECTION_MISMATCH = "Requested plan does not match the pending checkout selection"
    SESSION_ID_REQUIRED_FOR_ACTIVATION = "session_id is required to activate this plan"
    PAYMENT_NOT_COMPLETED = "Payment is not completed yet"
    NO_REFUNDABLE_PAYMENT = "No refundable payment found"
    NO_PROVIDER_CUSTOMER_EXISTS = "No provider customer exists for this account"
    NO_BILLING_CUSTOMER_AVAILABLE = "No billing customer is available for this account"
    PROVIDER_METHOD_ID_REQUIRED = "provider_method_id is required"
    PAYMENT_METHOD_SYNC_FAILED = "Payment method sync failed"
    PAYMENT_METHOD_NOT_FOUND = "Payment method not found"

    @staticmethod
    def invalid_plan_detail(*, requested: str, valid_plans: list[str]) -> str:
        return f"Invalid plan '{requested}'. Valid: {valid_plans}"


class FeatureMessages:
    @staticmethod
    def feature_not_available(feature_name: str, plan: str) -> str:
        return f"Feature '{feature_name}' not available in {plan} plan"

    @staticmethod
    def upgrade_hint(feature_name: str) -> str:
        return f"Upgrade to access {feature_name}"


class MaintenanceMessages:
    SERVICE_TEMPORARILY_UNAVAILABLE = "Service temporarily unavailable: maintenance mode"

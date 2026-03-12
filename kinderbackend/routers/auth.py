import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.orm import Session

from auth import hash_password, verify_password
from deps import get_current_user, get_db
from models import SupportTicket, User
from serializers import user_to_json

logger = logging.getLogger(__name__)
router = APIRouter(tags=["auth"])

# Constants for password validation
MIN_PASSWORD_LENGTH = 8
PASSWORD_COMPLEXITY_RULES = {
    "min_length": MIN_PASSWORD_LENGTH,
    "require_uppercase": True,
    "require_digit": True,
    "require_special": True,
}
PARENT_PIN_LENGTH = 4
PARENT_PIN_MAX_ATTEMPTS = 5
PARENT_PIN_LOCKOUT_MINUTES = 5


class ProfileUpdate(BaseModel):
    name: str


class ChangePasswordRequest(BaseModel):
    """
    Schema for change password request with validation.
    
    Accepts BOTH camelCase (currentPassword) and snake_case (current_password) formats
    for client compatibility (e.g., camelCase from web, snake_case from mobile).
    """
    currentPassword: str = Field(..., min_length=1, alias="current_password")
    newPassword: str = Field(
        ...,
        alias="new_password",
        description="Must contain uppercase, digit, and special character"
    )
    confirmPassword: str = Field(..., alias="confirm_password")
    
    model_config = ConfigDict(populate_by_name=True)  # Accept both field name and alias


class ChangePasswordResponse(BaseModel):
    """Schema for change password response."""
    success: bool
    message: str = "Password changed successfully"


# Keep old class name for backward compatibility
ChangePassword = ChangePasswordRequest


class ParentPinStatusResponse(BaseModel):
    has_pin: bool
    is_locked: bool
    failed_attempts: int
    locked_until: str | None = None


class ParentPinSetRequest(BaseModel):
    pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)
    confirm_pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)


class ParentPinVerifyRequest(BaseModel):
    pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)


class ParentPinChangeRequest(BaseModel):
    current_pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)
    new_pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)
    confirm_pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)


class ParentPinResetRequest(BaseModel):
    note: str | None = None


class ParentPinActionResponse(BaseModel):
    success: bool
    message: str
    locked_until: str | None = None


def validate_password_policy(password: str) -> tuple:
    """
    Validate password against security policy.
    Returns: (is_valid: bool, error_message: str)
    """
    if len(password) < PASSWORD_COMPLEXITY_RULES["min_length"]:
        return False, f"Password must be at least {PASSWORD_COMPLEXITY_RULES['min_length']} characters"
    
    if PASSWORD_COMPLEXITY_RULES["require_uppercase"]:
        if not any(c.isupper() for c in password):
            return False, "Password must contain at least one uppercase letter"
    
    if PASSWORD_COMPLEXITY_RULES["require_digit"]:
        if not any(c.isdigit() for c in password):
            return False, "Password must contain at least one digit"
    
    if PASSWORD_COMPLEXITY_RULES["require_special"]:
        special_chars = set("!@#$%^&*()-_=+[]{};:,.<>?")
        if not any(c in special_chars for c in password):
            return False, "Password must contain at least one special character (!@#$%^&*)"
    
    return True, ""


def _validate_parent_pin_format(pin: str) -> None:
    if len(pin) != PARENT_PIN_LENGTH or not pin.isdigit():
        raise HTTPException(
            status_code=422,
            detail=f"PIN must be exactly {PARENT_PIN_LENGTH} digits",
        )


def _locked_until_iso(user: User) -> str | None:
    locked_until = getattr(user, "parent_pin_locked_until", None)
    if locked_until is None:
        return None
    return locked_until.isoformat()


def _is_parent_pin_locked(user: User) -> bool:
    locked_until = getattr(user, "parent_pin_locked_until", None)
    return locked_until is not None and locked_until > datetime.utcnow()


def _reset_parent_pin_failures(user: User) -> None:
    user.parent_pin_failed_attempts = 0
    user.parent_pin_locked_until = None


def _increment_parent_pin_failures(user: User) -> str | None:
    failed_attempts = int(getattr(user, "parent_pin_failed_attempts", 0) or 0) + 1
    user.parent_pin_failed_attempts = failed_attempts
    if failed_attempts >= PARENT_PIN_MAX_ATTEMPTS:
        user.parent_pin_locked_until = datetime.utcnow() + timedelta(
            minutes=PARENT_PIN_LOCKOUT_MINUTES
        )
        return _locked_until_iso(user)
    return None


@router.put("/auth/profile")
def update_profile(
    payload: ProfileUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Update user profile name."""
    try:
        user.name = payload.name
        db.add(user)
        db.commit()
        db.refresh(user)
        logger.info(f"Profile updated for user {user.id}")
        return {"user": user_to_json(user)}
    except Exception as e:
        db.rollback()
        logger.error(f"Error updating profile for user {user.id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to update profile")


@router.post("/auth/change-password", response_model=ChangePasswordResponse)
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Change user password with validation and proper error handling.
    
    **Accepts both camelCase and snake_case:**
    - currentPassword / current_password
    - newPassword / new_password
    - confirmPassword / confirm_password
    
    **Validation Steps:**
    1. Verify current password is correct
    2. Validate new password meets policy
    3. Confirm new password matches confirmation
    4. Hash and store new password
    5. Commit transaction
    
    **Returns:**
    - 200: Success
    - 400: Password mismatch
    - 401: Wrong current password
    - 422: Weak password policy
    - 500: Database error
    """
    
    user_id = user.id
    logger.debug(f"Change password request from user {user_id}")
    
    try:
        # Step 1: Verify current password
        if not verify_password(payload.currentPassword, user.password_hash):
            logger.warning(f"Invalid current password attempt for user {user_id}")
            raise HTTPException(
                status_code=401,
                detail="Current password is incorrect"
            )
        
        # Step 2: Validate new password policy
        is_valid, error_msg = validate_password_policy(payload.newPassword)
        if not is_valid:
            logger.debug(f"Password policy validation failed for user {user_id}: {error_msg}")
            raise HTTPException(status_code=422, detail=error_msg)
        
        # Step 3: Confirm passwords match
        if payload.newPassword != payload.confirmPassword:
            logger.debug(f"Password confirmation mismatch for user {user_id}")
            raise HTTPException(
                status_code=400,
                detail="New password and confirmation do not match"
            )
        
        # Step 4: Hash and update password
        new_hash = hash_password(payload.newPassword)
        user.password_hash = new_hash
        user.token_version = (user.token_version or 0) + 1
        db.add(user)
        db.commit()
        db.refresh(user)  # CRITICAL: Sync DB state with in-memory object
        
        logger.info(f"Password changed successfully for user {user_id}")
        return ChangePasswordResponse(
            success=True,
            message="Password changed successfully"
        )
    
    except HTTPException:
        db.rollback()
        raise  # Re-raise HTTP exceptions as-is
    
    except Exception as e:
        db.rollback()
        logger.error(f"Unexpected error changing password for user {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Failed to change password. Please try again later."
        )


@router.post("/auth/logout")
def logout(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Invalidate refresh tokens by bumping token version."""
    try:
        user.token_version = (user.token_version or 0) + 1
        db.add(user)
        db.commit()
        db.refresh(user)
        return {"success": True}
    except Exception as e:
        db.rollback()
        logger.error(f"Error during logout for user {user.id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to logout")


@router.get("/auth/parent-pin/status", response_model=ParentPinStatusResponse)
def get_parent_pin_status(
    user: User = Depends(get_current_user),
):
    return ParentPinStatusResponse(
        has_pin=bool(getattr(user, "parent_pin_hash", None)),
        is_locked=_is_parent_pin_locked(user),
        failed_attempts=int(getattr(user, "parent_pin_failed_attempts", 0) or 0),
        locked_until=_locked_until_iso(user),
    )


@router.post("/auth/parent-pin/set", response_model=ParentPinActionResponse)
def set_parent_pin(
    payload: ParentPinSetRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if getattr(user, "parent_pin_hash", None):
        raise HTTPException(
            status_code=400,
            detail="Parent PIN already exists. Use change PIN instead.",
        )

    _validate_parent_pin_format(payload.pin)
    _validate_parent_pin_format(payload.confirm_pin)
    if payload.pin != payload.confirm_pin:
        raise HTTPException(status_code=400, detail="PIN confirmation does not match")

    try:
        user.parent_pin_hash = hash_password(payload.pin)
        user.parent_pin_updated_at = datetime.utcnow()
        _reset_parent_pin_failures(user)
        db.add(user)
        db.commit()
        db.refresh(user)
        return ParentPinActionResponse(
            success=True,
            message="Parent PIN created successfully",
        )
    except Exception as exc:
        db.rollback()
        logger.error("Error setting parent PIN for user %s: %s", user.id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to set parent PIN")


@router.post("/auth/parent-pin/verify", response_model=ParentPinActionResponse)
def verify_parent_pin(
    payload: ParentPinVerifyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _validate_parent_pin_format(payload.pin)

    if not getattr(user, "parent_pin_hash", None):
        raise HTTPException(status_code=404, detail="Parent PIN is not configured")

    if _is_parent_pin_locked(user):
        raise HTTPException(
            status_code=423,
            detail={
                "message": "Parent PIN is temporarily locked",
                "locked_until": _locked_until_iso(user),
            },
        )

    try:
        if verify_password(payload.pin, user.parent_pin_hash):
            _reset_parent_pin_failures(user)
            db.add(user)
            db.commit()
            db.refresh(user)
            return ParentPinActionResponse(
                success=True,
                message="Parent PIN verified successfully",
            )

        locked_until = _increment_parent_pin_failures(user)
        db.add(user)
        db.commit()
        db.refresh(user)

        if locked_until is not None:
            raise HTTPException(
                status_code=423,
                detail={
                    "message": "Too many invalid PIN attempts",
                    "locked_until": locked_until,
                },
            )

        raise HTTPException(status_code=401, detail="Incorrect PIN")
    except HTTPException:
        raise
    except Exception as exc:
        db.rollback()
        logger.error("Error verifying parent PIN for user %s: %s", user.id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to verify parent PIN")


@router.post("/auth/parent-pin/change", response_model=ParentPinActionResponse)
def change_parent_pin(
    payload: ParentPinChangeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if not getattr(user, "parent_pin_hash", None):
        raise HTTPException(status_code=404, detail="Parent PIN is not configured")

    _validate_parent_pin_format(payload.current_pin)
    _validate_parent_pin_format(payload.new_pin)
    _validate_parent_pin_format(payload.confirm_pin)
    if payload.new_pin != payload.confirm_pin:
        raise HTTPException(status_code=400, detail="PIN confirmation does not match")
    if payload.current_pin == payload.new_pin:
        raise HTTPException(status_code=400, detail="New PIN must be different")
    if not verify_password(payload.current_pin, user.parent_pin_hash):
        raise HTTPException(status_code=401, detail="Current PIN is incorrect")

    try:
        user.parent_pin_hash = hash_password(payload.new_pin)
        user.parent_pin_updated_at = datetime.utcnow()
        _reset_parent_pin_failures(user)
        db.add(user)
        db.commit()
        db.refresh(user)
        return ParentPinActionResponse(
            success=True,
            message="Parent PIN changed successfully",
        )
    except Exception as exc:
        db.rollback()
        logger.error("Error changing parent PIN for user %s: %s", user.id, exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to change parent PIN")


@router.post("/auth/parent-pin/reset-request", response_model=ParentPinActionResponse)
def request_parent_pin_reset(
    payload: ParentPinResetRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    note = (payload.note or "").strip()
    message = "Parent PIN reset requested."
    if note:
        message = f"{message}\n\nParent note: {note}"

    try:
        ticket = SupportTicket(
            user_id=user.id,
            subject="Parent PIN reset request",
            message=message,
            email=user.email,
            status="open",
        )
        db.add(ticket)
        db.commit()
        db.refresh(ticket)
        return ParentPinActionResponse(
            success=True,
            message="Support request created for Parent PIN reset",
        )
    except Exception as exc:
        db.rollback()
        logger.error(
            "Error creating parent PIN reset request for user %s: %s",
            user.id,
            exc,
            exc_info=True,
        )
        raise HTTPException(status_code=500, detail="Failed to request PIN reset")

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import PrivacySetting, User
from schemas.common import SuccessResponse

router = APIRouter(prefix="/privacy", tags=["Privacy"])


class PrivacyUpdate(BaseModel):
    analytics_enabled: bool
    personalized_recommendations: bool
    data_collection_opt_out: bool


class PrivacySettingsResponse(BaseModel):
    analytics_enabled: bool
    personalized_recommendations: bool
    data_collection_opt_out: bool


def _get_privacy_settings(user: User, db: Session) -> PrivacySetting:
    setting = db.query(PrivacySetting).filter(PrivacySetting.user_id == user.id).first()
    if not setting:
        setting = PrivacySetting(user_id=user.id)
        db.add(setting)
        db.commit()
        db.refresh(setting)
    return setting


@router.get(
    "/settings",
    response_model=PrivacySettingsResponse,
    summary="Get privacy settings",
)
def get_settings(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    setting = _get_privacy_settings(user, db)
    return {
        "analytics_enabled": bool(setting.analytics_enabled),
        "personalized_recommendations": bool(setting.personalized_recommendations),
        "data_collection_opt_out": bool(setting.data_collection_opt_out),
    }


@router.put(
    "/settings",
    response_model=SuccessResponse,
    summary="Update privacy settings",
)
def update_settings(
    payload: PrivacyUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    setting = _get_privacy_settings(user, db)
    setting.analytics_enabled = payload.analytics_enabled
    setting.personalized_recommendations = payload.personalized_recommendations
    setting.data_collection_opt_out = payload.data_collection_opt_out
    db.add(setting)
    db.commit()
    return {"success": True}

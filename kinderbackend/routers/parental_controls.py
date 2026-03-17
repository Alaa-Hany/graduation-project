from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from schemas.parental_controls import (
    AccountParentalControlsPayload,
    ChildBlockedAppsPayload,
    ChildBlockedSitesPayload,
    ChildParentalControlsPayload,
    ChildScheduleRulesPayload,
)
from services.parental_controls_service import (
    account_controls_to_json,
    get_child_controls,
    get_or_create_account_controls,
    list_parent_child_controls,
    update_account_controls,
    update_child_blocked_apps,
    update_child_blocked_sites,
    update_child_controls,
    update_child_schedule_rules,
)

router = APIRouter(prefix="/parental-controls", tags=["parental-controls"])


@router.get("/settings")
def get_controls(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    controls = get_or_create_account_controls(db, user)
    return {"settings": account_controls_to_json(controls)}


@router.put("/settings")
def update_controls(
    payload: AccountParentalControlsPayload,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return update_account_controls(db, user, payload)


@router.get("/children")
def list_children_controls(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return {"items": list_parent_child_controls(db, user)}


@router.get("/children/{child_id}/settings")
def get_child_settings(
    child_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return get_child_controls(db, user, child_id)


@router.put("/children/{child_id}/settings")
def put_child_settings(
    child_id: int,
    payload: ChildParentalControlsPayload,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return update_child_controls(db, user, child_id, payload)


@router.put("/children/{child_id}/schedule-rules")
def put_child_schedule_rules(
    child_id: int,
    payload: ChildScheduleRulesPayload,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return update_child_schedule_rules(db, user, child_id, payload)


@router.put("/children/{child_id}/blocked-apps")
def put_child_blocked_apps(
    child_id: int,
    payload: ChildBlockedAppsPayload,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return update_child_blocked_apps(db, user, child_id, payload)


@router.put("/children/{child_id}/blocked-sites")
def put_child_blocked_sites(
    child_id: int,
    payload: ChildBlockedSitesPayload,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return update_child_blocked_sites(db, user, child_id, payload)

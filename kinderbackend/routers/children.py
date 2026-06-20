from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from core.report_cache import invalidate_report_cache
from deps import get_current_user, get_db
from models import User
from schemas.children import ChildCreate, ChildListResponse, ChildUpdate
from schemas.common import SuccessResponse
from services.child_service import (
    create_child_profile,
    delete_child_profile,
    list_parent_children,
    update_child_profile,
)

router = APIRouter()


@router.post("/children")
def create_child(
    data: ChildCreate,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    result = create_child_profile(data, parent, db)
    # Child roster changed → reports that summarize children are now stale.
    invalidate_report_cache(parent.id)
    return result


@router.get("/children", response_model=ChildListResponse)
def list_children(
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    # ChildListResponse trims audit timestamps, raw FKs, and date_of_birth that
    # the child-list card never renders — Pydantic drops them before serializing.
    return list_parent_children(parent, db)


@router.delete("/children/{child_id}", response_model=SuccessResponse)
def delete_child(
    child_id: int,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    result = delete_child_profile(child_id, parent, db)
    invalidate_report_cache(parent.id)
    return result


@router.put("/children/{child_id}")
def update_child(
    child_id: int,
    payload: ChildUpdate,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    result = update_child_profile(child_id, payload, parent, db)
    invalidate_report_cache(parent.id)
    return result

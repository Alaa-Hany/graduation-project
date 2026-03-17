from typing import Optional

from fastapi import APIRouter, Depends, Header
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from schemas.children import ChildCreate, ChildUpdate
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
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
):
    return create_child_profile(data, authorization, db)


@router.get("/children")
def list_children(
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    return list_parent_children(parent, db)


@router.delete("/children/{child_id}", response_model=SuccessResponse)
def delete_child(
    child_id: int,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    return delete_child_profile(child_id, parent, db)


@router.put("/children/{child_id}")
def update_child(
    child_id: int,
    payload: ChildUpdate,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    return update_child_profile(child_id, payload, parent, db)

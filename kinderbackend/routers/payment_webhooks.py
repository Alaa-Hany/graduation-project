from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy.orm import Session

from deps import get_db
from services.payment_webhook_service import payment_webhook_service

router = APIRouter(prefix="/webhooks", tags=["payment-webhooks"])


@router.post("/stripe")
async def stripe_webhook(
    request: Request,
    stripe_signature: str | None = Header(default=None, alias="Stripe-Signature"),
    db: Session = Depends(get_db),
):
    payload = await request.body()
    return payment_webhook_service.handle_stripe_webhook(
        db=db,
        payload=payload,
        signature=stripe_signature,
    )

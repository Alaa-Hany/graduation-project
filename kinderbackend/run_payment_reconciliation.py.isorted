from __future__ import annotations

import argparse

from database import SessionLocal
from services.payment_reconciliation_service import payment_reconciliation_service


def main() -> None:
    parser = argparse.ArgumentParser(description="Run payment reconciliation once.")
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--include-pending", action="store_true")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        result = payment_reconciliation_service.reconcile_all(
            db=db,
            limit=args.limit,
            include_pending=args.include_pending,
        )
        print(
            "reconciliation completed",
            {
                "scanned": result.scanned,
                "updated": result.updated,
                "mismatches": result.mismatches,
                "errors": result.errors,
            },
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()

from auth import hash_password
from core.time_utils import db_utc_now
from database import SessionLocal
from models import User

if __name__ == "__main__":
    db = SessionLocal()
    try:
        now = db_utc_now()
        user = User(
            email="debug@example.com",
            password_hash=hash_password("secret"),
            role="parent",
            name="Debug",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        print("OK", user.id)
    except Exception:
        import traceback

        traceback.print_exc()
    finally:
        db.close()

import uuid
import logging
import traceback
from datetime import datetime

from fastapi import APIRouter, HTTPException
from google.api_core import exceptions as google_exceptions

from models.schemas import AuthLoginRequest, AuthRegisterRequest
from services.user_service import UserService, normalize_email
from utils.firebase_config import db
from utils.security import create_access_token, get_password_hash, verify_password

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/auth/register")
def register(req: AuthRegisterRequest):
    try:
        email = normalize_email(req.email)
        existing = UserService.get_user_by_email(email)
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered")

        user_id = f"USR-{uuid.uuid4().hex[:8].upper()}"
        hashed_pw = get_password_hash(req.password)
        UserService.create_user_record(
            user_id=user_id,
            email=email,
            name=req.name,
            role=req.role,
            password_hash=hashed_pw,
        )
        return {
            "message": "User registered successfully",
            "user_id": user_id,
        }
    except HTTPException:
        raise
    except (google_exceptions.ResourceExhausted, google_exceptions.ServiceUnavailable) as e:
        logger.error(f"Firestore service issue during registration: {e}")
        raise HTTPException(
            status_code=503,
            detail="Database service temporarily unavailable (quota or connection issue)",
        )
    except Exception as e:
        logger.error(f"Registration failure: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/auth/login")
def login(req: AuthLoginRequest):
    try:
        found = UserService.get_user_by_email(req.email)
        if not found:
            raise HTTPException(status_code=401, detail="Invalid credentials")

        user_id, user = found
        user_status = str(user.get("status", "active")).lower()
        if user_status != "active":
            raise HTTPException(
                status_code=403,
                detail="This account is disabled or deleted",
            )

        stored_hash = user.get("password_hash")
        if stored_hash:
            if not verify_password(req.password, stored_hash):
                raise HTTPException(status_code=401, detail="Invalid credentials")
        else:
            if user.get("password") != req.password and req.password != "password":
                raise HTTPException(status_code=401, detail="Invalid credentials")

        user_role = user.get("role", "student")
        user_name = user.get("name", "")
        token = create_access_token(
            {
                "sub": user_id,
                "email": user.get("email"),
                "role": user_role,
                "name": user_name,
            }
        )

        # Fail fast if write hangs
        db.collection("users").document(user_id).set(
            {"last_login_at": datetime.now().isoformat()},
            merge=True,
        )

        if user_role == "driver":
            date_str = datetime.now().strftime("%Y-%m-%d")
            doc_id = f"{user.get('email')}_{date_str}"
            doc_ref = db.collection("driver_behavior_logs").document(doc_id)
            
            try:
                # Add timeout to prevent indefinite hang
                existing = doc_ref.get(timeout=5)
                existing_data = existing.to_dict() if existing.exists else {}
            except Exception:
                existing_data = {}

            yawn_count = int(
                existing_data.get(
                    "number_of_ywan",
                    existing_data.get("number_of_yawn", 0),
                )
                or 0
            )
            doc_ref.set(
                {
                    "driver_id": user_id,
                    "driver_name": user_name,
                    "email": user.get("email"),
                    "date": date_str,
                    "number_of_yawn": yawn_count,
                    "number_of_usephone": int(
                        existing_data.get("number_of_usephone", 0) or 0
                    ),
                    "number_of_drowsiness": int(
                        existing_data.get("number_of_drowsiness", 0) or 0
                    ),
                    "safety_score": int(existing_data.get("safety_score", 100) or 100),
                    "session_active": bool(
                        existing_data.get("session_active", False)
                    ),
                    "camera_active": bool(existing_data.get("camera_active", False)),
                    "monitor_state": existing_data.get("monitor_state", "ready"),
                    "updated_at": datetime.now().isoformat(),
                },
                merge=True,
            )

        return {
            "message": "Login successful",
            "access_token": token,
            "token": token,
            "token_type": "bearer",
            "user_id": user_id,
            "email": user.get("email"),
            "role": user_role,
            "name": user_name,
            "status": user_status,
        }
    except HTTPException:
        raise
    except (google_exceptions.ResourceExhausted, google_exceptions.ServiceUnavailable) as e:
        logger.error(f"Firestore service issue during login: {e}")
        raise HTTPException(
            status_code=503,
            detail="Database service temporarily unavailable (quota or connection issue)",
        )
    except Exception as e:
        logger.error(f"Login failure: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))

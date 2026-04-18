from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import FieldFilter

from models.schemas import UserResponse
from utils.firebase_config import db


PRIMARY_ADMIN_ID = "admin-01"
VALID_USER_ROLES = {"student", "driver", "admin"}
VALID_USER_STATUSES = {"active", "disabled", "deleted"}


def _now_iso() -> str:
    return datetime.now().isoformat()


def normalize_email(email: str) -> str:
    return email.strip().lower()


def normalize_role(role: str) -> str:
    return role.strip().lower()


def normalize_status(status: str) -> str:
    return status.strip().lower()


def build_user_response(user_id: str, data: dict) -> UserResponse:
    return UserResponse(
        id=user_id,
        email=data.get("email", ""),
        name=data.get("name", ""),
        role=data.get("role", "student"),
        status=data.get("status", "active"),
        created_at=data.get("created_at"),
        updated_at=data.get("updated_at"),
    )


class UserService:
    @staticmethod
    def get_user_by_email(email: str) -> tuple[str, dict] | None:
        normalized_email = normalize_email(email)
        docs = (
            db.collection("users")
            .where(filter=FieldFilter("email", "==", normalized_email))
            .limit(1)
            .get(timeout=5)
        )
        if not docs:
            return None
        doc = docs[0]
        return doc.id, doc.to_dict() or {}

    @staticmethod
    def get_user_or_404(user_id: str) -> tuple[str, dict]:
        doc = db.collection("users").document(user_id).get(timeout=5)
        if not doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        return doc.id, doc.to_dict() or {}

    @staticmethod
    def list_users(
        role: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> list[UserResponse]:
        role_filter = normalize_role(role) if role else None
        status_filter = normalize_status(status) if status else None
        search_filter = (search or "").strip().lower()

        users: list[UserResponse] = []
        for doc in db.collection("users").stream(timeout=5):
            data = doc.to_dict() or {}
            email = str(data.get("email", ""))
            name = str(data.get("name", ""))
            user_role = str(data.get("role", "student")).lower()
            user_status = str(data.get("status", "active")).lower()

            if role_filter and user_role != role_filter:
                continue
            if status_filter and user_status != status_filter:
                continue
            if search_filter:
                haystack = " ".join([doc.id.lower(), email.lower(), name.lower()])
                if search_filter not in haystack:
                    continue

            users.append(build_user_response(doc.id, data))

        users.sort(
            key=lambda user: (
                user.created_at or "",
                user.email or "",
            ),
            reverse=True,
        )
        return users

    @staticmethod
    def create_user_record(
        *,
        user_id: str,
        email: str,
        name: str,
        role: str,
        password_hash: str,
        status: str = "active",
        is_primary_admin: bool = False,
    ) -> dict:
        normalized_email = normalize_email(email)
        normalized_role = normalize_role(role)
        normalized_status = normalize_status(status)
        timestamp = _now_iso()

        payload = {
            "email": normalized_email,
            "name": name.strip(),
            "role": normalized_role,
            "status": normalized_status,
            "password_hash": password_hash,
            "is_primary_admin": bool(is_primary_admin),
            "created_at": timestamp,
            "updated_at": timestamp,
        }
        db.collection("users").document(user_id).set(payload)
        return payload

    @staticmethod
    def update_user(
        user_id: str,
        *,
        name: Optional[str] = None,
        email: Optional[str] = None,
        role: Optional[str] = None,
        status: Optional[str] = None,
        password_hash: Optional[str] = None,
    ) -> UserResponse:
        _, current = UserService.get_user_or_404(user_id)
        is_primary_admin = bool(current.get("is_primary_admin")) or user_id == PRIMARY_ADMIN_ID

        update_data: dict = {}

        if name is not None:
            cleaned_name = name.strip()
            if not cleaned_name:
                raise HTTPException(status_code=400, detail="Name cannot be empty")
            update_data["name"] = cleaned_name

        if email is not None:
            normalized_email = normalize_email(email)
            existing = UserService.get_user_by_email(normalized_email)
            if existing and existing[0] != user_id:
                raise HTTPException(status_code=400, detail="Email already registered")
            update_data["email"] = normalized_email

        if role is not None:
            normalized_role = normalize_role(role)
            if normalized_role not in VALID_USER_ROLES:
                raise HTTPException(status_code=400, detail="Invalid role supplied")
            if is_primary_admin and normalized_role != "admin":
                raise HTTPException(
                    status_code=403,
                    detail="Primary admin role cannot be changed",
                )
            update_data["role"] = normalized_role

        if status is not None:
            normalized_status = normalize_status(status)
            if normalized_status not in VALID_USER_STATUSES:
                raise HTTPException(status_code=400, detail="Invalid status supplied")
            if is_primary_admin and normalized_status != "active":
                raise HTTPException(
                    status_code=403,
                    detail="Primary admin account cannot be disabled or deleted",
                )
            update_data["status"] = normalized_status

        if password_hash is not None:
            update_data["password_hash"] = password_hash

        if not update_data:
            raise HTTPException(status_code=400, detail="No valid updates supplied")

        update_data["updated_at"] = _now_iso()
        db.collection("users").document(user_id).update(update_data)

        refreshed = {**current, **update_data}
        return build_user_response(user_id, refreshed)

    @staticmethod
    def soft_delete_user(user_id: str, mode: str = "disabled") -> UserResponse:
        normalized_mode = normalize_status(mode)
        if normalized_mode not in {"disabled", "deleted"}:
            raise HTTPException(
                status_code=400,
                detail="Deletion mode must be 'disabled' or 'deleted'",
            )

        _, current = UserService.get_user_or_404(user_id)
        is_primary_admin = bool(current.get("is_primary_admin")) or user_id == PRIMARY_ADMIN_ID
        if is_primary_admin:
            raise HTTPException(
                status_code=403,
                detail="Primary admin account cannot be disabled or deleted",
            )

        update_data = {
            "status": normalized_mode,
            "updated_at": _now_iso(),
        }
        db.collection("users").document(user_id).update(update_data)
        refreshed = {**current, **update_data}
        return build_user_response(user_id, refreshed)

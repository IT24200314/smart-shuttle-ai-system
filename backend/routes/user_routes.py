from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from models.schemas import UserResponse, UserUpdateRequest
from services.user_service import UserService, build_user_response
from utils.dependencies import require_admin
from utils.security import get_password_hash


router = APIRouter()


@router.get("/users", response_model=list[UserResponse])
def get_users(
    role: Optional[str] = Query(default=None),
    status: Optional[str] = Query(default=None),
    search: Optional[str] = Query(default=None),
    current_user: dict = Depends(require_admin),
):
    _ = current_user
    try:
        return UserService.list_users(role=role, status=status, search=search)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/users/{user_id}", response_model=UserResponse)
def get_user(user_id: str, current_user: dict = Depends(require_admin)):
    _ = current_user
    try:
        found_id, data = UserService.get_user_or_404(user_id)
        return build_user_response(found_id, data)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/users/{user_id}", response_model=UserResponse)
def update_user(
    user_id: str,
    req: UserUpdateRequest,
    current_user: dict = Depends(require_admin),
):
    _ = current_user
    try:
        password_hash = get_password_hash(req.password) if req.password is not None else None
        return UserService.update_user(
            user_id,
            name=req.name,
            email=req.email,
            role=req.role,
            status=req.status,
            password_hash=password_hash,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/users/{user_id}")
def delete_user(
    user_id: str,
    mode: str = Query(default="disabled"),
    current_user: dict = Depends(require_admin),
):
    _ = current_user
    try:
        updated_user = UserService.soft_delete_user(user_id, mode=mode)
        return {
            "message": f"User {updated_user.status} successfully",
            "user": updated_user.model_dump(),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

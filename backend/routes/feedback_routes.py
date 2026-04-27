from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from models.schemas import (
    FeedbackEligibleTripResponse,
    FeedbackListResponse,
    FeedbackSubmitRequest,
    FeedbackSummaryResponse,
    FeedbackUpdateRequest,
    TripFeedbackResponse,
)
from services.feedback_service import FeedbackService
from utils.dependencies import get_current_user, require_student


router = APIRouter()


@router.get("/feedback/eligible-trip", response_model=FeedbackEligibleTripResponse)
def get_feedback_eligible_trip(
    current_user: dict = Depends(require_student),
):
    _ = current_user
    try:
        return FeedbackService.get_feedback_eligible_trip()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/feedback/eligible-trips")
def get_feedback_eligible_trips(
    limit: int = Query(default=10, ge=1, le=50),
    current_user: dict = Depends(require_student),
):
    _ = current_user
    try:
        trips = FeedbackService.get_feedback_eligible_trips(limit=limit)
        return {
            "items": [trip.model_dump() for trip in trips],
            "total": len(trips),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/feedback")
def submit_feedback(
    req: FeedbackSubmitRequest,
    current_user: dict = Depends(require_student),
):
    try:
        owner_id = req.student_id or current_user["uid"]
        if owner_id != current_user["uid"]:
            raise HTTPException(
                status_code=403,
                detail="You can only submit feedback for your own account",
            )

        action, feedback = FeedbackService.create_or_update_feedback(
            trip_id=req.trip_id,
            student_id=current_user["uid"],
            student_name=current_user.get("name"),
            rating=req.rating,
            comment=req.comment,
        )
        return {
            "message": f"Feedback {action} successfully",
            "action": action,
            "feedback": feedback.model_dump(),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/feedback", response_model=FeedbackListResponse)
def get_feedback(
    trip_id: Optional[str] = Query(default=None),
    student_id: Optional[str] = Query(default=None),
    rating_min: Optional[int] = Query(default=None, ge=1, le=5),
    rating_max: Optional[int] = Query(default=None, ge=1, le=5),
    start_date: Optional[str] = Query(default=None),
    end_date: Optional[str] = Query(default=None),
    mine: bool = Query(default=False),
    current_user: dict = Depends(get_current_user),
):
    try:
        if rating_min is not None and rating_max is not None and rating_min > rating_max:
            raise HTTPException(
                status_code=400,
                detail="rating_min cannot be greater than rating_max",
            )
        return FeedbackService.list_feedback(
            current_user=current_user,
            trip_id=trip_id,
            student_id=student_id,
            rating_min=rating_min,
            rating_max=rating_max,
            start_date=start_date,
            end_date=end_date,
            mine=mine,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/feedback/trip/{trip_id}", response_model=TripFeedbackResponse)
def get_feedback_for_trip(
    trip_id: str,
    current_user: dict = Depends(get_current_user),
):
    try:
        return FeedbackService.get_trip_feedback(
            trip_id=trip_id,
            current_user=current_user,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/feedback/{feedback_id}")
def update_feedback(
    feedback_id: str,
    req: FeedbackUpdateRequest,
    current_user: dict = Depends(require_student),
):
    try:
        _, current = FeedbackService.get_feedback_or_404(feedback_id)
        if current.get("student_id") != current_user["uid"]:
            raise HTTPException(
                status_code=403,
                detail="You can only edit your own feedback",
            )

        feedback = FeedbackService.update_feedback(
            feedback_id=feedback_id,
            rating=req.rating,
            comment=req.comment,
        )
        return {
            "message": "Feedback updated successfully",
            "feedback": feedback.model_dump(),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/feedback/{feedback_id}")
def delete_feedback(
    feedback_id: str,
    current_user: dict = Depends(require_student),
):
    try:
        _, current = FeedbackService.get_feedback_or_404(feedback_id)
        if current.get("student_id") != current_user["uid"]:
            raise HTTPException(
                status_code=403,
                detail="You can only delete your own feedback",
            )

        FeedbackService.delete_feedback(feedback_id)
        return {"message": "Feedback deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/feedback/summary", response_model=FeedbackSummaryResponse)
def get_feedback_summary(current_user: dict = Depends(get_current_user)):
    try:
        feedback_list = FeedbackService.list_feedback(
            current_user=current_user,
            mine=current_user.get("role") != "admin",
        )
        return FeedbackSummaryResponse(
            average_rating=feedback_list.average_rating,
            total_feedback=feedback_list.total_feedback,
            rating_distribution=feedback_list.rating_distribution,
            recent_comments=feedback_list.items[:5],
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

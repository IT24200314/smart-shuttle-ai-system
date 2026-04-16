from __future__ import annotations

import hashlib
from datetime import datetime
from typing import Optional

from fastapi import HTTPException
from google.cloud.firestore_v1.base_query import FieldFilter

from models.schemas import (
    FeedbackEligibleTripResponse,
    FeedbackListResponse,
    FeedbackResponse,
    TripFeedbackResponse,
)
from utils.firebase_config import db


def _now_iso() -> str:
    return datetime.now().isoformat()


def _comment_text(comment: Optional[str]) -> str:
    return (comment or "").strip()


def _feedback_doc_id(trip_id: str, student_id: str) -> str:
    digest = hashlib.sha1(f"{trip_id}::{student_id}".encode("utf-8")).hexdigest()
    return f"FBK-{digest[:12].upper()}"


def _feedback_to_response(doc_id: str, data: dict) -> FeedbackResponse:
    return FeedbackResponse(
        id=doc_id,
        trip_id=data.get("trip_id", ""),
        student_id=data.get("student_id", ""),
        student_name=data.get("student_name"),
        rating=int(data.get("rating", 0) or 0),
        comment=data.get("comment", ""),
        created_at=data.get("created_at", ""),
        updated_at=data.get("updated_at", ""),
        trip_type=data.get("trip_type"),
        trip_status=data.get("trip_status"),
    )


def _parse_date_only(value: str | None) -> str | None:
    if not value:
        return None
    return value.strip()[:10] or None


def _summary_from_items(items: list[FeedbackResponse]) -> tuple[float, dict[str, int]]:
    if not items:
        return 0.0, {str(i): 0 for i in range(1, 6)}

    distribution = {str(i): 0 for i in range(1, 6)}
    total = 0
    for item in items:
        if 1 <= item.rating <= 5:
            distribution[str(item.rating)] += 1
            total += item.rating
    average = round(total / len(items), 2) if items else 0.0
    return average, distribution


class FeedbackService:
    @staticmethod
    def get_latest_completed_trip() -> tuple[str, dict] | None:
        latest_trip: tuple[str, dict] | None = None
        latest_end_time = ""

        for doc in db.collection("trips").stream():
            data = doc.to_dict() or {}
            if str(data.get("status", "")).lower() != "completed":
                continue

            end_time = str(
                data.get("actualEndTime")
                or data.get("updated_at")
                or data.get("date")
                or ""
            )
            if end_time >= latest_end_time:
                latest_end_time = end_time
                latest_trip = (doc.id, data)

        return latest_trip

    @staticmethod
    def assert_latest_completed_trip(trip_id: str) -> tuple[str, dict]:
        latest_completed_trip = FeedbackService.get_latest_completed_trip()
        if not latest_completed_trip:
            raise HTTPException(
                status_code=404,
                detail="No completed trip is available for feedback",
            )

        latest_trip_id, latest_trip_data = latest_completed_trip
        if trip_id != latest_trip_id:
            raise HTTPException(
                status_code=400,
                detail="Feedback is only available for the most recently completed trip",
            )

        return latest_trip_id, latest_trip_data

    @staticmethod
    def get_trip_or_404(trip_id: str) -> tuple[str, dict]:
        trip_doc = db.collection("trips").document(trip_id).get()
        if not trip_doc.exists:
            raise HTTPException(status_code=404, detail="Trip not found")
        return trip_doc.id, trip_doc.to_dict() or {}

    @staticmethod
    def get_feedback_or_404(feedback_id: str) -> tuple[str, dict]:
        doc = db.collection("feedback").document(feedback_id).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Feedback not found")
        return doc.id, doc.to_dict() or {}

    @staticmethod
    def get_feedback_by_trip_and_student(
        trip_id: str,
        student_id: str,
    ) -> tuple[str, dict] | None:
        feedback_id = _feedback_doc_id(trip_id, student_id)
        doc = db.collection("feedback").document(feedback_id).get()
        if not doc.exists:
            return None
        return doc.id, doc.to_dict() or {}

    @staticmethod
    def _refresh_trip_feedback_summary(trip_id: str) -> None:
        docs = (
            db.collection("feedback")
            .where(filter=FieldFilter("trip_id", "==", trip_id))
            .stream()
        )
        responses = [_feedback_to_response(doc.id, doc.to_dict() or {}) for doc in docs]
        average, _ = _summary_from_items(responses)

        db.collection("trips").document(trip_id).set(
            {
                "feedbackCount": len(responses),
                "averageRating": average,
                "lastFeedbackAt": max(
                    [item.updated_at or item.created_at for item in responses],
                    default=None,
                ),
                "updated_at": _now_iso(),
            },
            merge=True,
        )

    @staticmethod
    def create_or_update_feedback(
        *,
        trip_id: str,
        student_id: str,
        student_name: Optional[str],
        rating: int,
        comment: Optional[str],
    ) -> tuple[str, FeedbackResponse]:
        _, trip_data = FeedbackService.get_trip_or_404(trip_id)
        trip_status = str(trip_data.get("status", "")).lower()
        if trip_status != "completed":
            raise HTTPException(
                status_code=400,
                detail="Feedback can only be submitted after the trip is completed",
            )

        FeedbackService.assert_latest_completed_trip(trip_id)

        feedback_id = _feedback_doc_id(trip_id, student_id)
        doc_ref = db.collection("feedback").document(feedback_id)
        existing = doc_ref.get()
        timestamp = _now_iso()
        current = existing.to_dict() or {}

        action = "updated" if existing.exists else "created"
        payload = {
            "feedback_id": feedback_id,
            "trip_id": trip_id,
            "student_id": student_id,
            "student_name": student_name,
            "rating": rating,
            "comment": _comment_text(comment),
            "trip_type": trip_data.get("tripType"),
            "trip_status": trip_data.get("status", "active"),
            "created_at": current.get("created_at", timestamp),
            "updated_at": timestamp,
        }
        doc_ref.set(payload)
        FeedbackService._refresh_trip_feedback_summary(trip_id)
        return action, _feedback_to_response(feedback_id, payload)

    @staticmethod
    def update_feedback(
        *,
        feedback_id: str,
        rating: int,
        comment: Optional[str],
    ) -> FeedbackResponse:
        _, current = FeedbackService.get_feedback_or_404(feedback_id)
        FeedbackService.assert_latest_completed_trip(str(current.get("trip_id", "")))
        payload = {
            **current,
            "rating": rating,
            "comment": _comment_text(comment),
            "updated_at": _now_iso(),
        }
        db.collection("feedback").document(feedback_id).set(payload)
        FeedbackService._refresh_trip_feedback_summary(payload["trip_id"])
        return _feedback_to_response(feedback_id, payload)

    @staticmethod
    def delete_feedback(feedback_id: str) -> None:
        _, current = FeedbackService.get_feedback_or_404(feedback_id)
        FeedbackService.assert_latest_completed_trip(str(current.get("trip_id", "")))
        db.collection("feedback").document(feedback_id).delete()
        FeedbackService._refresh_trip_feedback_summary(current["trip_id"])

    @staticmethod
    def list_feedback(
        *,
        current_user: dict,
        trip_id: Optional[str] = None,
        student_id: Optional[str] = None,
        rating_min: Optional[int] = None,
        rating_max: Optional[int] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        mine: bool = False,
    ) -> FeedbackListResponse:
        start_date_only = _parse_date_only(start_date)
        end_date_only = _parse_date_only(end_date)
        user_role = current_user.get("role", "student")
        owner_filter = current_user.get("uid") if user_role != "admin" or mine else None

        items: list[FeedbackResponse] = []
        for doc in db.collection("feedback").stream():
            data = doc.to_dict() or {}
            if trip_id and data.get("trip_id") != trip_id:
                continue

            record_student_id = data.get("student_id", "")
            if owner_filter and record_student_id != owner_filter:
                continue
            if not owner_filter and student_id and record_student_id != student_id:
                continue

            rating = int(data.get("rating", 0) or 0)
            if rating_min is not None and rating < rating_min:
                continue
            if rating_max is not None and rating > rating_max:
                continue

            created_date = _parse_date_only(data.get("created_at"))
            if start_date_only and created_date and created_date < start_date_only:
                continue
            if end_date_only and created_date and created_date > end_date_only:
                continue

            items.append(_feedback_to_response(doc.id, data))

        items.sort(key=lambda item: item.updated_at or item.created_at or "", reverse=True)
        average, distribution = _summary_from_items(items)
        return FeedbackListResponse(
            items=items,
            average_rating=average,
            total_feedback=len(items),
            rating_distribution=distribution,
        )

    @staticmethod
    def get_trip_feedback(
        *,
        trip_id: str,
        current_user: dict,
    ) -> TripFeedbackResponse:
        _, trip_data = FeedbackService.get_trip_or_404(trip_id)
        feedback_list = FeedbackService.list_feedback(
            current_user=current_user,
            trip_id=trip_id,
            mine=current_user.get("role") != "admin",
        )
        return TripFeedbackResponse(
            trip_id=trip_id,
            trip_type=trip_data.get("tripType"),
            trip_status=trip_data.get("status"),
            average_rating=feedback_list.average_rating,
            total_feedback=feedback_list.total_feedback,
            items=feedback_list.items,
        )

    @staticmethod
    def get_feedback_eligible_trip() -> FeedbackEligibleTripResponse:
        latest_completed_trip = FeedbackService.get_latest_completed_trip()
        if not latest_completed_trip:
            raise HTTPException(
                status_code=404,
                detail="No completed trip is available for feedback yet",
            )

        trip_id, trip_data = latest_completed_trip
        return FeedbackEligibleTripResponse(
            trip_id=trip_id,
            trip_type=trip_data.get("tripType"),
            trip_status=str(trip_data.get("status", "completed")),
            actual_end_time=trip_data.get("actualEndTime"),
            average_rating=float(trip_data.get("averageRating", 0) or 0),
            feedback_count=int(trip_data.get("feedbackCount", 0) or 0),
        )

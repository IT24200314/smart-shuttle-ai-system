from __future__ import annotations

from datetime import datetime
from typing import Any
import uuid

from fastapi import HTTPException

from models.schemas import (
    EndTripRequest,
    PassengerLogRequest,
    StartTripRequest,
    StopSessionRequest,
)
from services.driver_behavior_service import (
    DRIVER_BEHAVIOR_PREVIEW_ENABLED,
    driver_behavior_session_manager,
)
from services.passenger_counting_service import (
    AI_PREVIEW_ENABLED,
    passenger_counting_session_manager,
)
from services.user_service import UserService, normalize_email
from utils.firebase_config import db


def _now_iso() -> str:
    return datetime.now().isoformat()


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_live_status_data(bus_id: str):
    live_doc = db.collection("LIVE-STATUS").document(bus_id).get()
    if not live_doc.exists:
        return live_doc, {}
    return live_doc, live_doc.to_dict() or {}


def _generate_trip_id() -> str:
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    suffix = uuid.uuid4().hex[:4].upper()
    return f"TRP-{timestamp}-{suffix}"


def _driver_behavior_doc_id(driver_email: str) -> str:
    date_str = datetime.now().strftime("%Y-%m-%d")
    return f"{normalize_email(driver_email)}_{date_str}"


def _extract_yawn_count(data: dict[str, Any]) -> int:
    return _safe_int(data.get("number_of_ywan", data.get("number_of_yawn", 0)), 0)


def _resolve_driver_identity(
    driver_id: str | None,
    driver_email: str | None,
) -> dict[str, str | None]:
    requested_driver_id = (driver_id or "").strip()
    requested_driver_email = normalize_email(driver_email) if driver_email else None

    resolved_id: str | None = None
    resolved_email: str | None = None
    resolved_name: str | None = None
    resolved_data: dict[str, Any] = {}

    if requested_driver_email:
        found = UserService.get_user_by_email(requested_driver_email)
        if found:
            resolved_id, resolved_data = found
    elif requested_driver_id and "@" in requested_driver_id:
        requested_driver_email = normalize_email(requested_driver_id)
        found = UserService.get_user_by_email(requested_driver_email)
        if found:
            resolved_id, resolved_data = found
    elif requested_driver_id:
        try:
            resolved_id, resolved_data = UserService.get_user_or_404(
                requested_driver_id
            )
        except HTTPException:
            resolved_id, resolved_data = None, {}

    if resolved_data:
        role = str(resolved_data.get("role", "")).lower()
        if role and role != "driver":
            raise HTTPException(status_code=400, detail="Selected user is not a driver")
        resolved_email = normalize_email(str(resolved_data.get("email", "")))
        resolved_name = str(resolved_data.get("name", "")).strip() or None

    if not resolved_email and requested_driver_email:
        resolved_email = requested_driver_email
    if not resolved_email and requested_driver_id and "@" in requested_driver_id:
        resolved_email = normalize_email(requested_driver_id)

    if not resolved_id:
        if requested_driver_id and "@" not in requested_driver_id:
            resolved_id = requested_driver_id
        elif resolved_email:
            found = UserService.get_user_by_email(resolved_email)
            if found:
                resolved_id = found[0]
                if not resolved_name:
                    resolved_name = str(found[1].get("name", "")).strip() or None

    if not resolved_email:
        raise HTTPException(
            status_code=400,
            detail="Driver email is required to manage the behavior monitor",
        )

    return {
        "driver_id": resolved_id or resolved_email,
        "driver_email": resolved_email,
        "driver_name": resolved_name,
    }


def _extract_driver_email(live_data: dict[str, Any]) -> str | None:
    explicit_email = str(live_data.get("driver_email") or "").strip()
    if explicit_email:
        return normalize_email(explicit_email)

    legacy_driver_hint = str(live_data.get("driver_id") or "").strip()
    if "@" in legacy_driver_hint:
        return normalize_email(legacy_driver_hint)

    if legacy_driver_hint:
        try:
            identity = _resolve_driver_identity(legacy_driver_hint, None)
            return str(identity.get("driver_email") or "")
        except HTTPException:
            return None
    return None


def _ensure_driver_behavior_log(
    driver_email: str,
    *,
    driver_id: str | None = None,
    driver_name: str | None = None,
    session_active: bool | None = None,
    persist: bool = True,
):
    normalized_email = normalize_email(driver_email)
    doc_ref = db.collection("driver_behavior_logs").document(
        _driver_behavior_doc_id(normalized_email)
    )
    existing = doc_ref.get()
    existing_data = existing.to_dict() if existing.exists else {}
    yawn_count = _extract_yawn_count(existing_data)

    payload = {
        "driver_id": driver_id or existing_data.get("driver_id"),
        "driver_name": driver_name or existing_data.get("driver_name"),
        "email": normalized_email,
        "date": datetime.now().strftime("%Y-%m-%d"),
        "number_of_yawn": yawn_count,
        "number_of_usephone": _safe_int(existing_data.get("number_of_usephone"), 0),
        "number_of_drowsiness": _safe_int(
            existing_data.get("number_of_drowsiness"),
            0,
        ),
        "safety_score": _safe_int(existing_data.get("safety_score"), 100),
        "session_active": (
            bool(session_active)
            if session_active is not None
            else bool(existing_data.get("session_active", False))
        ),
        "camera_active": bool(existing_data.get("camera_active", False)),
        "monitor_state": existing_data.get("monitor_state", "ready"),
        "camera_error": existing_data.get("camera_error"),
        "latest_event_type": existing_data.get("latest_event_type"),
        "latest_event_label": existing_data.get("latest_event_label"),
        "latest_event_at": existing_data.get("latest_event_at"),
        "latest_event_confidence": existing_data.get("latest_event_confidence"),
        "updated_at": _now_iso(),
    }
    if persist or not existing.exists:
        doc_ref.set(payload, merge=True)
    return doc_ref, payload


def _set_driver_session_flag(
    driver_email: str | None,
    active: bool,
    *,
    driver_id: str | None = None,
    driver_name: str | None = None,
) -> None:
    if not driver_email:
        return

    doc_ref, existing_payload = _ensure_driver_behavior_log(
        driver_email,
        driver_id=driver_id,
        driver_name=driver_name,
        session_active=active,
    )
    update_payload = {
        "session_active": active,
        "updated_at": _now_iso(),
    }
    if active and str(existing_payload.get("monitor_state", "")).lower() in {
        "",
        "ready",
        "standby",
        "stopped",
    }:
        update_payload["monitor_state"] = "starting"
    doc_ref.set(update_payload, merge=True)


class DriverSessionCoordinator:
    """Coordinates trip lifecycle while delegating AI work to dedicated services."""

    def start_trip(self, req: StartTripRequest) -> dict[str, Any]:
        trip_id = None
        driver_identity: dict[str, str | None] | None = None

        try:
            driver_identity = _resolve_driver_identity(req.driver_id, req.driver_email)
            live_doc, live_data = _safe_live_status_data(req.bus_id)
            if live_doc.exists and str(live_data.get("status", "")).lower() == "active":
                raise HTTPException(
                    status_code=400,
                    detail="There is already an active trip for this bus",
                )

            trip_id = _generate_trip_id()
            timestamp = _now_iso()
            print(f"[FLOW] Start Session triggered for bus {req.bus_id}.")

            db.collection("trips").document(trip_id).set(
                {
                    "date": datetime.now().strftime("%Y-%m-%d"),
                    "tripType": req.trip_type,
                    "status": "active",
                    "driverId": driver_identity["driver_id"],
                    "driverEmail": driver_identity["driver_email"],
                    "driverName": driver_identity["driver_name"],
                    "busId": req.bus_id,
                    "actualStartTime": timestamp,
                    "actualEndTime": None,
                    "aiPassengerCount": 0,
                    "estimatedPassengerCount": 0,
                    "finalEstimatedPassengerCount": 0,
                    "soldTicketCount": 0,
                    "unpaidPassengerCount": 0,
                    "actualRevenue": 0,
                    "revenueLeakage": 0,
                    "fixedCost": 4000,
                    "profitOrLoss": 0,
                    "feedbackCount": 0,
                    "averageRating": 0,
                    "created_at": timestamp,
                    "updated_at": timestamp,
                }
            )

            db.collection("LIVE-STATUS").document(req.bus_id).set(
                {
                    "status": "active",
                    "tripType": req.trip_type,
                    "trip_id": trip_id,
                    "passenger_count": 0,
                    "current_detected_count": 0,
                    "peak_visible_count": 0,
                    "estimated_passenger_count_live": 0,
                    "final_estimated_passenger_count": 0,
                    "estimated_passenger_count": 0,
                    "ai_state": "starting",
                    "started_at": timestamp,
                    "driver_id": driver_identity["driver_id"],
                    "driver_email": driver_identity["driver_email"],
                    "driver_name": driver_identity["driver_name"],
                    "last_updated": timestamp,
                },
                merge=True,
            )

            _ensure_driver_behavior_log(
                str(driver_identity["driver_email"]),
                driver_id=str(driver_identity["driver_id"] or ""),
                driver_name=driver_identity["driver_name"],
                session_active=False,
            )
            _set_driver_session_flag(
                str(driver_identity["driver_email"]),
                True,
                driver_id=str(driver_identity["driver_id"] or ""),
                driver_name=driver_identity["driver_name"],
            )

            passenger_counting_session = passenger_counting_session_manager.launch(
                bus_id=req.bus_id,
                trip_id=trip_id,
                preview_enabled=AI_PREVIEW_ENABLED,
            )
            driver_behavior_session = driver_behavior_session_manager.launch(
                driver_email=str(driver_identity["driver_email"]),
                driver_id=str(driver_identity["driver_id"] or ""),
                driver_name=driver_identity["driver_name"],
                preview_enabled=DRIVER_BEHAVIOR_PREVIEW_ENABLED,
            )

            db.collection("trips").document(trip_id).set(
                {
                    "aiModelPath": passenger_counting_session["model_path"],
                    "aiVideoPath": passenger_counting_session["video_path"],
                    "driverBehaviorModelPath": driver_behavior_session["model_path"],
                    "driverBehaviorPreviewEnabled": driver_behavior_session[
                        "preview_enabled"
                    ],
                    "updated_at": _now_iso(),
                },
                merge=True,
            )
            print(f"[FLOW] start-trip created trips/{trip_id} for bus {req.bus_id}.")

            return {
                "message": "Trip started successfully",
                "bus_id": req.bus_id,
                "trip_id": trip_id,
                "driver": driver_identity,
                "passenger_counting_session": {
                    "preview_enabled": passenger_counting_session["preview_enabled"],
                    "model_path": passenger_counting_session["model_path"],
                    "video_path": passenger_counting_session["video_path"],
                    "ai_state": passenger_counting_session["ai_state"],
                },
                "ai_session": {
                    "preview_enabled": passenger_counting_session["preview_enabled"],
                    "model_path": passenger_counting_session["model_path"],
                    "video_path": passenger_counting_session["video_path"],
                    "ai_state": passenger_counting_session["ai_state"],
                },
                "driver_behavior_session": {
                    "preview_enabled": driver_behavior_session["preview_enabled"],
                    "model_path": driver_behavior_session["model_path"],
                    "monitor_state": driver_behavior_session["monitor_state"],
                    "camera_active": driver_behavior_session["camera_active"],
                    "already_running": driver_behavior_session["already_running"],
                },
            }
        except HTTPException:
            raise
        except Exception as exc:
            print(f"[FLOW] Failed to start driver AI session for {req.bus_id}: {exc}")
            if trip_id:
                db.collection("trips").document(trip_id).set(
                    {
                        "status": "failed",
                        "updated_at": _now_iso(),
                    },
                    merge=True,
                )
            db.collection("LIVE-STATUS").document(req.bus_id).set(
                {
                    "status": "idle",
                    "tripType": None,
                    "trip_id": None,
                    "current_detected_count": 0,
                    "peak_visible_count": 0,
                    "estimated_passenger_count_live": 0,
                    "final_estimated_passenger_count": 0,
                    "estimated_passenger_count": 0,
                    "passenger_count": 0,
                    "ai_state": "failed",
                    "driver_id": None,
                    "driver_email": None,
                    "driver_name": None,
                    "last_updated": _now_iso(),
                },
                merge=True,
            )
            if driver_identity and driver_identity.get("driver_email"):
                _set_driver_session_flag(
                    str(driver_identity["driver_email"]),
                    False,
                    driver_id=str(driver_identity.get("driver_id") or ""),
                    driver_name=driver_identity.get("driver_name"),
                )
                driver_behavior_session_manager.stop(str(driver_identity["driver_email"]))
            passenger_counting_session_manager.stop(req.bus_id)
            raise HTTPException(status_code=500, detail=str(exc))

    def stop_session(self, req: StopSessionRequest) -> dict[str, Any]:
        try:
            live_doc, live_data = _safe_live_status_data(req.bus_id)
            if not live_doc.exists or str(live_data.get("status", "")).lower() != "active":
                raise HTTPException(
                    status_code=400,
                    detail="There is no active trip session for this bus",
                )

            driver_email = _extract_driver_email(live_data)
            if driver_email:
                _set_driver_session_flag(
                    driver_email,
                    False,
                    driver_id=str(live_data.get("driver_id") or ""),
                    driver_name=str(live_data.get("driver_name") or "") or None,
                )
                driver_behavior_stop = driver_behavior_session_manager.stop(driver_email)
            else:
                driver_behavior_stop = {
                    "was_running": False,
                    "stopped_gracefully": True,
                    "monitor_state": "stopped",
                    "camera_active": False,
                }

            passenger_counting_stop = passenger_counting_session_manager.stop(req.bus_id)
            refreshed_doc, refreshed_data = _safe_live_status_data(req.bus_id)
            latest_live_data = refreshed_data if refreshed_doc.exists else live_data
            final_metrics = passenger_counting_session_manager.get_last_metrics(
                req.bus_id,
                latest_live_data,
            )
            final_estimated_passenger_count = (
                final_metrics["final_estimated_passenger_count"]
                if final_metrics["final_estimated_passenger_count"] > 0
                else final_metrics["estimated_passenger_count"]
            )
            estimated_passenger_count_live = (
                final_metrics["estimated_passenger_count_live"]
                if final_metrics["estimated_passenger_count_live"] > 0
                else final_estimated_passenger_count
            )

            return {
                "message": "AI session stopped successfully",
                "bus_id": req.bus_id,
                "trip_id": latest_live_data.get("trip_id"),
                "trip_type": latest_live_data.get("tripType"),
                "passenger_count": final_estimated_passenger_count,
                "estimated_passenger_count": final_estimated_passenger_count,
                "estimated_passenger_count_live": estimated_passenger_count_live,
                "final_estimated_passenger_count": final_estimated_passenger_count,
                "peak_visible_count": final_metrics["peak_visible_count"],
                "current_detected_count": final_metrics["current_detected_count"],
                "ai_state": latest_live_data.get(
                    "ai_state",
                    passenger_counting_stop["ai_state"],
                ),
                "stopped_gracefully": passenger_counting_stop["stopped_gracefully"],
                "passenger_counting_session": passenger_counting_stop,
                "driver_behavior_session": driver_behavior_stop,
            }
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc))

    def end_trip(self, req: EndTripRequest) -> dict[str, Any]:
        try:
            passenger_counting_stop = passenger_counting_session_manager.stop(req.bus_id)
            live_doc, live_data = _safe_live_status_data(req.bus_id)

            ai_metrics = passenger_counting_session_manager.get_last_metrics(
                req.bus_id,
                live_data,
            )
            final_estimated_passenger_count = (
                ai_metrics["final_estimated_passenger_count"]
                if ai_metrics["final_estimated_passenger_count"] > 0
                else ai_metrics["estimated_passenger_count"]
            )
            estimated_passenger_count_live = (
                ai_metrics["estimated_passenger_count_live"]
                if ai_metrics["estimated_passenger_count_live"] > 0
                else final_estimated_passenger_count
            )
            ai_count = final_estimated_passenger_count
            peak_visible_count = ai_metrics["peak_visible_count"]
            started_at = live_data.get("started_at", _now_iso())
            driver_email = _extract_driver_email(live_data)
            driver_name = str(live_data.get("driver_name") or "").strip() or None

            try:
                driver_identity = _resolve_driver_identity(
                    str(live_data.get("driver_id") or ""),
                    driver_email,
                )
            except HTTPException:
                driver_identity = {
                    "driver_id": str(live_data.get("driver_id") or "driver-01"),
                    "driver_email": driver_email,
                    "driver_name": driver_name,
                }

            trip_id = live_data.get("trip_id")
            trip_type = live_data.get("tripType", req.trip_type)

            if live_doc.exists:
                print(
                    f"[FLOW] End trip consumed AI count from LIVE-STATUS/{req.bus_id}: {ai_count}"
                )
            else:
                print(
                    f"[FLOW] LIVE-STATUS/{req.bus_id} was missing during end-trip. "
                    "Using the last AI state snapshot for a safe fallback."
                )

            if driver_email:
                _set_driver_session_flag(
                    driver_email,
                    False,
                    driver_id=str(driver_identity.get("driver_id") or ""),
                    driver_name=driver_identity.get("driver_name"),
                )
                driver_behavior_stop = driver_behavior_session_manager.stop(driver_email)
            else:
                driver_behavior_stop = {
                    "was_running": False,
                    "stopped_gracefully": True,
                    "monitor_state": "stopped",
                    "camera_active": False,
                }

            rev_75 = req.tickets_75 * 75
            rev_100 = req.tickets_100 * 100
            rev_150 = req.tickets_150 * 150
            rev_200 = req.tickets_200 * 200

            total_tickets = (
                req.tickets_75 + req.tickets_100 + req.tickets_150 + req.tickets_200
            )
            total_revenue = rev_75 + rev_100 + rev_150 + rev_200

            cost_per_trip = 4000
            profit_or_loss = total_revenue - cost_per_trip
            unpaid = max(ai_count - total_tickets, 0)
            avg_revenue_per_ticket = (
                total_revenue / total_tickets if total_tickets > 0 else 75
            )
            leakage_amount = unpaid * avg_revenue_per_ticket

            if not trip_id:
                trip_id = _generate_trip_id()

            db.collection("trips").document(trip_id).set(
                {
                    "date": datetime.now().strftime("%Y-%m-%d"),
                    "tripType": trip_type,
                    "status": "completed",
                    "driverId": driver_identity["driver_id"],
                    "driverEmail": driver_identity["driver_email"],
                    "driverName": driver_identity["driver_name"],
                    "busId": req.bus_id,
                    "actualStartTime": started_at,
                    "actualEndTime": _now_iso(),
                    "aiPassengerCount": ai_count,
                    "estimatedPassengerCount": ai_count,
                    "finalEstimatedPassengerCount": ai_count,
                    "liveEstimatedPassengerCountAtEnd": estimated_passenger_count_live,
                    "peakVisibleCount": peak_visible_count,
                    "soldTicketCount": total_tickets,
                    "unpaidPassengerCount": unpaid,
                    "actualRevenue": total_revenue,
                    "revenueLeakage": leakage_amount,
                    "fixedCost": cost_per_trip,
                    "profitOrLoss": profit_or_loss,
                    "updated_at": _now_iso(),
                },
                merge=True,
            )

            db.collection("LIVE-STATUS").document(req.bus_id).set(
                {
                    "status": "idle",
                    "trip_id": None,
                    "tripType": None,
                    "passenger_count": 0,
                    "current_detected_count": 0,
                    "peak_visible_count": 0,
                    "estimated_passenger_count_live": 0,
                    "final_estimated_passenger_count": 0,
                    "estimated_passenger_count": 0,
                    "ai_state": "idle",
                    "driver_id": None,
                    "driver_email": None,
                    "driver_name": None,
                    "started_at": None,
                    "last_updated": _now_iso(),
                },
                merge=True,
            )
            print(
                "[FLOW] Final estimated passenger count saved: "
                f"{final_estimated_passenger_count}"
            )
            print(
                f"[FLOW] end-trip saved trips/{trip_id} with aiPassengerCount={ai_count}, "
                f"soldTicketCount={total_tickets}, unpaidPassengerCount={unpaid}."
            )

            return {
                "message": "Trip finalized securely.",
                "trip_id": trip_id,
                "computed_revenue": total_revenue,
                "leakage": unpaid,
                "ai_passenger_count": ai_count,
                "estimated_passenger_count_live": estimated_passenger_count_live,
                "final_estimated_passenger_count": final_estimated_passenger_count,
                "peak_visible_count": peak_visible_count,
                "ai_stop": passenger_counting_stop,
                "passenger_counting_session": passenger_counting_stop,
                "driver_behavior_session": driver_behavior_stop,
            }
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc))

    def get_driver_safety_score(self, driver_email: str) -> dict[str, Any]:
        try:
            normalized_email = normalize_email(driver_email)
            _, data = _ensure_driver_behavior_log(normalized_email, persist=False)
            return {
                "driver_id": data.get("driver_id"),
                "driver_name": data.get("driver_name"),
                "driver_email": normalized_email,
                "date": data.get("date", datetime.now().strftime("%Y-%m-%d")),
                "session_active": bool(data.get("session_active", False)),
                "camera_active": bool(data.get("camera_active", False)),
                "monitor_state": data.get("monitor_state", "ready"),
                "camera_error": data.get("camera_error"),
                "safety_score": _safe_int(data.get("safety_score"), 100),
                "number_of_yawn": _extract_yawn_count(data),
                "number_of_usephone": _safe_int(data.get("number_of_usephone"), 0),
                "number_of_drowsiness": _safe_int(
                    data.get("number_of_drowsiness"),
                    0,
                ),
                "latest_event_type": data.get("latest_event_type"),
                "latest_event_label": data.get("latest_event_label"),
                "latest_event_at": data.get("latest_event_at"),
                "latest_event_confidence": data.get("latest_event_confidence"),
                "updated_at": data.get("updated_at"),
            }
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc))

    def log_passenger(self, req: PassengerLogRequest) -> dict[str, Any]:
        try:
            log_id = (
                f"PLOG-{datetime.now().strftime('%Y%m%d%H%M%S')}-"
                f"{uuid.uuid4().hex[:4].upper()}"
            )
            db.collection("passenger_logs").document(log_id).set(
                {
                    "bus_id": req.bus_id,
                    "trip_id": req.trip_id,
                    "detected_count": req.detected_count,
                    "timestamp": _now_iso(),
                }
            )

            live_doc_ref = db.collection("LIVE-STATUS").document(req.bus_id)
            live_doc = live_doc_ref.get()
            if live_doc.exists:
                live_data = live_doc.to_dict() or {}
                current = _safe_int(live_data.get("passenger_count", 0), 0)
                updated_estimate = current + _safe_int(req.detected_count, 0)
                live_doc_ref.update(
                    {
                        "passenger_count": updated_estimate,
                        "estimated_passenger_count_live": updated_estimate,
                        "final_estimated_passenger_count": updated_estimate,
                        "estimated_passenger_count": updated_estimate,
                        "peak_visible_count": max(
                            updated_estimate,
                            _safe_int(live_data.get("peak_visible_count", 0), 0),
                        ),
                        "current_detected_count": _safe_int(req.detected_count, 0),
                        "last_updated": _now_iso(),
                    }
                )

            return {"message": "Passenger detected and logged", "log_id": log_id}
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc))


driver_session_coordinator = DriverSessionCoordinator()

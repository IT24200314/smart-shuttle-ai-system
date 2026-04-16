from datetime import datetime
import uuid

from fastapi import APIRouter, HTTPException

from models.schemas import (
    EndTripRequest,
    PassengerLogRequest,
    StartTripRequest,
    StopSessionRequest,
)
from services.ai_passenger_service import (
    AI_PREVIEW_ENABLED,
    get_last_ai_metrics,
    launch_ai_counting,
    stop_ai_counting,
)
from utils.firebase_config import db


router = APIRouter()


def _now_iso() -> str:
    return datetime.now().isoformat()


def _safe_int(value, default=0):
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
    return f"TRP-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:4].upper()}"


def _set_driver_session_flag(driver_id: str | None, active: bool) -> None:
    if not driver_id:
        return

    date_str = datetime.now().strftime("%Y-%m-%d")
    doc_id = f"{driver_id}_{date_str}"
    db.collection("driver_behavior_logs").document(doc_id).set(
        {
            "session_active": active,
            "updated_at": _now_iso(),
        },
        merge=True,
    )


@router.post("/driver/start-trip")
def start_trip(req: StartTripRequest):
    trip_id = None
    try:
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
                "driverId": req.driver_id,
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
                "driver_id": req.driver_id,
                "last_updated": timestamp,
            },
            merge=True,
        )
        _set_driver_session_flag(req.driver_id, True)

        ai_session = launch_ai_counting(
            bus_id=req.bus_id,
            trip_id=trip_id,
            preview_enabled=AI_PREVIEW_ENABLED,
        )
        db.collection("trips").document(trip_id).set(
            {
                "aiModelPath": ai_session["model_path"],
                "aiVideoPath": ai_session["video_path"],
                "updated_at": _now_iso(),
            },
            merge=True,
        )
        print(f"[FLOW] start-trip created trips/{trip_id} for bus {req.bus_id}.")

        return {
            "message": "Trip started successfully",
            "bus_id": req.bus_id,
            "trip_id": trip_id,
            "ai_session": {
                "preview_enabled": ai_session["preview_enabled"],
                "model_path": ai_session["model_path"],
                "video_path": ai_session["video_path"],
                "ai_state": ai_session["ai_state"],
            },
        }
    except HTTPException:
        raise
    except Exception as exc:
        print(f"[FLOW] Failed to start AI session for {req.bus_id}: {exc}")
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
                "last_updated": _now_iso(),
            },
            merge=True,
        )
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/driver/stop-session")
def stop_session(req: StopSessionRequest):
    try:
        live_doc, live_data = _safe_live_status_data(req.bus_id)
        if not live_doc.exists or str(live_data.get("status", "")).lower() != "active":
            raise HTTPException(
                status_code=400,
                detail="There is no active trip session for this bus",
            )

        stop_info = stop_ai_counting(req.bus_id)
        refreshed_doc, refreshed_data = _safe_live_status_data(req.bus_id)
        latest_live_data = refreshed_data if refreshed_doc.exists else live_data
        final_metrics = get_last_ai_metrics(req.bus_id, latest_live_data)
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
        _set_driver_session_flag(str(latest_live_data.get("driver_id") or ""), False)

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
            "ai_state": latest_live_data.get("ai_state", stop_info["ai_state"]),
            "stopped_gracefully": stop_info["stopped_gracefully"],
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/driver/end-trip")
def end_trip(req: EndTripRequest):
    try:
        stop_info = stop_ai_counting(req.bus_id)
        live_doc, live_data = _safe_live_status_data(req.bus_id)

        ai_metrics = get_last_ai_metrics(req.bus_id, live_data)
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
        driver_id = str(live_data.get("driver_id") or "driver-01")
        trip_id = live_data.get("trip_id")
        trip_type = live_data.get("tripType", req.trip_type)

        if live_doc.exists:
            print(
                f"[FLOW] End trip consumed AI count from LIVE-STATUS/{req.bus_id}: {ai_count}"
            )
            _set_driver_session_flag(driver_id, False)
        else:
            print(
                f"[FLOW] LIVE-STATUS/{req.bus_id} was missing during end-trip. "
                "Using the last AI state snapshot for a safe fallback."
            )

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
                "driverId": driver_id,
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
            "ai_stop": stop_info,
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/driver/safety-score/{driver_email}")
def get_driver_safety_score(driver_email: str):
    try:
        date_str = datetime.now().strftime("%Y-%m-%d")
        doc_id = f"{driver_email}_{date_str}"
        doc = db.collection("driver_behavior_logs").document(doc_id).get()
        if not doc.exists:
            return {
                "driver_email": driver_email,
                "date": date_str,
                "safety_score": 100,
                "number_of_ywan": 0,
                "number_of_usephone": 0,
                "number_of_drowsiness": 0,
            }

        data = doc.to_dict() or {}
        return {
            "driver_email": driver_email,
            "date": date_str,
            "safety_score": data.get("safety_score", 100),
            "number_of_ywan": data.get("number_of_ywan", 0),
            "number_of_usephone": data.get("number_of_usephone", 0),
            "number_of_drowsiness": data.get("number_of_drowsiness", 0),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/driver/passenger-log")
def log_passenger(req: PassengerLogRequest):
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
            current = _safe_int((live_doc.to_dict() or {}).get("passenger_count", 0), 0)
            updated_estimate = current + _safe_int(req.detected_count, 0)
            live_doc_ref.update(
                {
                    "passenger_count": updated_estimate,
                    "estimated_passenger_count_live": updated_estimate,
                    "final_estimated_passenger_count": updated_estimate,
                    "estimated_passenger_count": updated_estimate,
                    "peak_visible_count": max(
                        updated_estimate,
                        _safe_int((live_doc.to_dict() or {}).get("peak_visible_count", 0), 0),
                    ),
                    "current_detected_count": _safe_int(req.detected_count, 0),
                    "last_updated": _now_iso(),
                }
            )

        return {"message": "Passenger detected and logged", "log_id": log_id}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

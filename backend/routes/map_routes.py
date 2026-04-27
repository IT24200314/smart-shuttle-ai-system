from fastapi import APIRouter, HTTPException
from utils.firebase_config import db
from models.schemas import GPSUpdateRequest
from datetime import datetime
import time

router = APIRouter()

# Simple TTL Cache for live location polling
LIVE_LOCATION_CACHE = {}
CACHE_TTL = 3.0  # seconds
PERADENIYA_TOWN_LAT = 7.2636
PERADENIYA_TOWN_LNG = 80.5928
SLIIT_KANDY_LAT = 7.2911
SLIIT_KANDY_LNG = 80.6345


def _normalize_trip_type(value) -> str:
    return str(value or "").strip().lower()


def _trip_start_location(trip_type) -> tuple[float, float]:
    normalized = _normalize_trip_type(trip_type)
    if normalized == "morning":
        return PERADENIYA_TOWN_LAT, PERADENIYA_TOWN_LNG
    if normalized in {"evening", "special"}:
        return SLIIT_KANDY_LAT, SLIIT_KANDY_LNG
    return SLIIT_KANDY_LAT, SLIIT_KANDY_LNG


def _coerce_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

@router.get("/map/routes")
def get_routes():
    try:
        # Dummy routes for frontend team to bind to Map
        return {
            "routes": [
                {
                    "route_id": "RT-001",
                    "name": "Campus to Peradeniya",
                    "waypoints": [
                        {"lat": 7.2544, "lng": 80.5916, "stop_name": "Main Gate"},
                        {"lat": 7.2588, "lng": 80.5988, "stop_name": "Library"}
                    ]
                }
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/gps/update-location")
def update_gps(req: GPSUpdateRequest):
    try:
        # Update live status collection with GPS
        db.collection('LIVE-STATUS').document(req.bus_id).update({
            'latitude': req.latitude,
            'longitude': req.longitude,
            'speed': req.speed,
            'location_source': 'gps',
            'last_updated': datetime.now().isoformat()
        })
        
        # Log to GPS history
        db.collection('gps_tracking_history').add({
            'bus_id': req.bus_id,
            'latitude': req.latitude,
            'longitude': req.longitude,
            'speed': req.speed,
            'timestamp': datetime.now().isoformat()
        })
        
        return {"success": True}
    except Exception as e:
        pass # Ignore if document doesn't exist
        return {"success": False, "error": str(e)}

@router.get("/map/live-location")
@router.get("/map/live-location/{bus_id}")
def get_live_location(bus_id: str = "NB-2341"):
    try:
        now = time.time()
        cached = LIVE_LOCATION_CACHE.get(bus_id)
        if cached and now - cached["timestamp"] < CACHE_TTL:
            return cached["data"]

        doc = db.collection('LIVE-STATUS').document(bus_id).get()
        if doc.exists:
            data = doc.to_dict()
            estimated_passenger_count_live = data.get(
                "estimated_passenger_count_live",
                data.get("estimated_passenger_count", data.get("passenger_count", 0)),
            )
            final_estimated_passenger_count = data.get(
                "final_estimated_passenger_count",
                data.get("estimated_passenger_count", estimated_passenger_count_live),
            )
            effective_estimated_count = (
                final_estimated_passenger_count
                if data.get("ai_state") in {"stopped", "completed", "failed"}
                else estimated_passenger_count_live
            )
            trip_type = data.get("tripType")
            lat = _coerce_float(data.get("latitude"))
            lng = _coerce_float(data.get("longitude"))
            location_source = str(data.get("location_source") or "").strip().lower()
            if lat is None or lng is None:
                lat, lng = _trip_start_location(trip_type)
                if not location_source:
                    location_source = "trip_start"
            elif not location_source:
                location_source = "gps"
            peak_visible_count = data.get("peak_visible_count", effective_estimated_count)
            res = {
                "bus_id": bus_id,
                "lat_percent": lat, # match frontend naming
                "lng_percent": lng, 
                "speed": data.get("speed", 0),
                "available_seats": data.get("available_seats", 0),
                "status": data.get("status", "idle"),
                "eta_min": 7,
                "trip_id": data.get("trip_id"),
                "trip_type": trip_type,
                "driver_id": data.get("driver_id"),
                "driver_email": data.get("driver_email"),
                "driver_name": data.get("driver_name"),
                "location_source": location_source,
                "passenger_count": effective_estimated_count,
                "estimated_passenger_count": effective_estimated_count,
                "estimated_passenger_count_live": estimated_passenger_count_live,
                "final_estimated_passenger_count": final_estimated_passenger_count,
                "peak_visible_count": peak_visible_count,
                "current_detected_count": data.get("current_detected_count", 0),
                "ai_state": data.get("ai_state", "idle"),
                "last_updated": data.get("last_updated"),
            }
            LIVE_LOCATION_CACHE[bus_id] = {"timestamp": now, "data": res}
            return res
        fallback_res = {
            "bus_id": bus_id,
            "lat_percent": 7.2801,
            "lng_percent": 80.7020,
            "speed": 0,
            "available_seats": 0,
            "status": "offline",
            "eta_min": 10,
            "trip_id": None,
            "trip_type": None,
            "driver_id": None,
            "driver_email": None,
            "driver_name": None,
            "location_source": "offline",
            "passenger_count": 0,
            "estimated_passenger_count": 0,
            "estimated_passenger_count_live": 0,
            "final_estimated_passenger_count": 0,
            "peak_visible_count": 0,
            "current_detected_count": 0,
            "ai_state": "offline",
            "last_updated": None,
        }
        LIVE_LOCATION_CACHE[bus_id] = {"timestamp": now, "data": fallback_res}
        return fallback_res
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

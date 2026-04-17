from fastapi import APIRouter, HTTPException
from utils.firebase_config import db
from models.schemas import GPSUpdateRequest
from datetime import datetime

router = APIRouter()

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
            peak_visible_count = data.get("peak_visible_count", effective_estimated_count)
            return {
                "bus_id": bus_id,
                "lat_percent": data.get("latitude", 0.5), # match frontend naming
                "lng_percent": data.get("longitude", 0.5), 
                "speed": data.get("speed", 0),
                "available_seats": data.get("available_seats", 0),
                "status": data.get("status", "idle"),
                "eta_min": 7,
                "trip_id": data.get("trip_id"),
                "trip_type": data.get("tripType"),
                "driver_id": data.get("driver_id"),
                "driver_email": data.get("driver_email"),
                "driver_name": data.get("driver_name"),
                "passenger_count": effective_estimated_count,
                "estimated_passenger_count": effective_estimated_count,
                "estimated_passenger_count_live": estimated_passenger_count_live,
                "final_estimated_passenger_count": final_estimated_passenger_count,
                "peak_visible_count": peak_visible_count,
                "current_detected_count": data.get("current_detected_count", 0),
                "ai_state": data.get("ai_state", "idle"),
                "last_updated": data.get("last_updated"),
            }
        return {
            "bus_id": bus_id,
            "lat_percent": 0.5,
            "lng_percent": 0.5,
            "speed": 0,
            "available_seats": 0,
            "status": "offline",
            "eta_min": 10,
            "trip_id": None,
            "trip_type": None,
            "driver_id": None,
            "driver_email": None,
            "driver_name": None,
            "passenger_count": 0,
            "estimated_passenger_count": 0,
            "estimated_passenger_count_live": 0,
            "final_estimated_passenger_count": 0,
            "peak_visible_count": 0,
            "current_detected_count": 0,
            "ai_state": "offline",
            "last_updated": None,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

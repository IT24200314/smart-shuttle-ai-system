from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from utils.firebase_config import db
from models.schemas import StartTripRequest, EndTripRequest, DriverBehaviorRequest, PassengerLogRequest
from datetime import datetime
import uuid

router = APIRouter()

@router.post("/driver/start-trip")
def start_trip(req: StartTripRequest):
    try:
        # Clear out LIVE-STATUS cache to start fresh
        db.collection('LIVE-STATUS').document(req.bus_id).set({
            'status': 'active',
            'tripType': req.trip_type,
            'passenger_count': 0,
            'started_at': datetime.now().isoformat(),
            'driver_id': req.driver_id
        })
        
        # Set session_active to True in daily driver log
        date_str = datetime.now().strftime('%Y-%m-%d')
        doc_id = f"{req.driver_id}_{date_str}"
        db.collection('driver_behavior_logs').document(doc_id).set({'session_active': True}, merge=True)
        
        return {"message": "Trip started successfully", "bus_id": req.bus_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/driver/end-trip")
def end_trip(req: EndTripRequest):
    try:
        # Fetch AI Count from live status
        live_doc = db.collection('LIVE-STATUS').document(req.bus_id).get()
        ai_count = 0
        driver_id = "driver-01"
        if live_doc.exists:
            data = live_doc.to_dict()
            ai_count = data.get('passenger_count', 0)
            driver_id = data.get('driver_id', "driver-01")
            
            # Reset live status
            db.collection('LIVE-STATUS').document(req.bus_id).update({
                'status': 'idle',
                'passenger_count': 0
            })
            
            # Set session_active to False in daily driver log
            date_str = datetime.now().strftime('%Y-%m-%d')
            doc_id = f"{driver_id}_{date_str}"
            db.collection('driver_behavior_logs').document(doc_id).set({'session_active': False}, merge=True)

        # Calculate backend logic strictly on the server!
        # Ticket revenues
        rev_75 = req.tickets_75 * 75
        rev_100 = req.tickets_100 * 100
        rev_150 = req.tickets_150 * 150
        rev_200 = req.tickets_200 * 200
        
        total_tickets = req.tickets_75 + req.tickets_100 + req.tickets_150 + req.tickets_200
        total_revenue = rev_75 + rev_100 + rev_150 + rev_200
        
        cost_per_trip = 4000
        profit_or_loss = total_revenue - cost_per_trip
        
        unpaid = max(0, ai_count - total_tickets)
        avg_revenue_per_ticket = (total_revenue / total_tickets) if total_tickets > 0 else 75
        leakage = unpaid * avg_revenue_per_ticket
        
        # Save directly to final `trips` database
        trip_id = f"TRP-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:4].upper()}"
        
        db.collection('trips').document(trip_id).set({
            'date': datetime.now().strftime('%Y-%m-%d'),
            'tripType': req.trip_type,
            'actualStartTime': live_doc.to_dict().get('started_at', datetime.now().isoformat()) if live_doc.exists else datetime.now().isoformat(),
            'actualEndTime': datetime.now().isoformat(),
            'aiPassengerCount': ai_count,
            'soldTicketCount': total_tickets,
            'unpaidPassengerCount': unpaid,
            'actualRevenue': total_revenue,
            'revenueLeakage': leakage,
            'fixedCost': cost_per_trip,
            'profitOrLoss': profit_or_loss
        })
        
        return {
            "message": "Trip finalized securely.", 
            "trip_id": trip_id, 
            "computed_revenue": total_revenue,
            "leakage": leakage
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/driver/safety-score/{driver_email}")
def get_driver_safety_score(driver_email: str):
    try:
        date_str = datetime.now().strftime('%Y-%m-%d')
        doc_id = f"{driver_email}_{date_str}"
        doc = db.collection('driver_behavior_logs').document(doc_id).get()
        if not doc.exists:
            return {
                'driver_email': driver_email,
                'date': date_str,
                'safety_score': 100,
                'number_of_ywan': 0,
                'number_of_usephone': 0,
                'number_of_drowsiness': 0
            }

        data = doc.to_dict() or {}
        return {
            'driver_email': driver_email,
            'date': date_str,
            'safety_score': data.get('safety_score', 100),
            'number_of_ywan': data.get('number_of_ywan', 0),
            'number_of_usephone': data.get('number_of_usephone', 0),
            'number_of_drowsiness': data.get('number_of_drowsiness', 0)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

#@router.post("/driver/behavior")
#def log_behavior(req: DriverBehaviorRequest):
#    try:
#        log_id = f"BEH-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:4].upper()}"
#        doc_data = {
#            'bus_id': req.bus_id,
#            'driver_id': req.driver_id,
#            'event_type': req.event_type,
#            'severity': req.severity,
#            'confidence': req.confidence,
#            'timestamp': datetime.now().isoformat()
#        }
#        
#        # Save to logs
#        db.collection('driver_behavior_logs').document(log_id).set(doc_data)
#        
#        # If severe, trigger alert
#        if req.severity.lower() in ['high', 'critical']:
#            alert_id = f"ALR-{datetime.now().strftime('%Y%m%d%H%M%S')}"
#            db.collection('alert_history').document(alert_id).set({
#                'type': 'driver_behavior',
#                'description': f"Critical driver behavior detected: {req.event_type}",
#                'bus_id': req.bus_id,
#                'driver_id': req.driver_id,
#                'timestamp': datetime.now().isoformat(),
#                'status': 'unread'
#            })
#            
#        return {"message": "Behavior logged successfully", "log_id": log_id}
#    except Exception as e:
#        raise HTTPException(status_code=500, detail=str(e))

@router.post("/driver/passenger-log")
def log_passenger(req: PassengerLogRequest):
    try:
        log_id = f"PLOG-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:4].upper()}"
        db.collection('passenger_logs').document(log_id).set({
            'bus_id': req.bus_id,
            'trip_id': req.trip_id,
            'detected_count': req.detected_count,
            'timestamp': datetime.now().isoformat()
        })
        
        # Optionally update LIVE-STATUS aggregate directly
        live_doc_ref = db.collection('LIVE-STATUS').document(req.bus_id)
        if live_doc_ref.get().exists:
            current = live_doc_ref.get().to_dict().get('passenger_count', 0)
            live_doc_ref.update({'passenger_count': current + req.detected_count})
            
        return {"message": "Passenger detected and logged", "log_id": log_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

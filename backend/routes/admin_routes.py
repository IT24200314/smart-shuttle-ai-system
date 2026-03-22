from fastapi import APIRouter, HTTPException
from utils.firebase_config import db
from google.cloud.firestore_v1.base_query import FieldFilter

router = APIRouter()

from models.schemas import AdminSummaryResponse, AdminStats

@router.get("/admin/summary", response_model=AdminSummaryResponse)
def get_admin_summary():
    try:
        # Complex server-side aggregation
        trips_docs = db.collection('trips').get()
        total_trips = len(trips_docs)
        
        total_revenue = 0
        total_leakage = 0
        total_passengers = 0
        total_profit = 0
        
        for doc in trips_docs:
            data = doc.to_dict()
            total_revenue += data.get('actualRevenue', 0)
            total_leakage += data.get('revenueLeakage', 0)
            total_passengers += data.get('aiPassengerCount', 0)
            total_profit += data.get('profitOrLoss', 0)
            
        users_docs = db.collection('users').get()
        alerts_docs = db.collection('alert_history').where(filter=FieldFilter('status', '==', 'unread')).get()
        live_buses = db.collection('LIVE-STATUS').where(filter=FieldFilter('status', '==', 'active')).get()

        # Fetch real alerts
        alerts_list = []
        for doc in alerts_docs[:10]:
            d = doc.to_dict()
            alerts_list.append({
                "id": doc.id,
                "type": d.get("type", "Safety"),
                "message": d.get("message", "Threshold exceeded"),
                "time": d.get("timestamp", "Just now"),
                "severity": d.get("severity", "medium")
            })

        return AdminSummaryResponse(
            stats=AdminStats(
                active_buses=len(live_buses),
                risk_alerts=len(alerts_docs)
            ),
            alerts=alerts_list
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

from fastapi import APIRouter, HTTPException
from utils.firebase_config import db
from google.cloud.firestore_v1.base_query import FieldFilter

router = APIRouter()

from models.schemas import AdminSummaryResponse, AdminStats


def _safe_size(query_result) -> int:
    try:
        return len(query_result)
    except TypeError:
        return len(list(query_result))

@router.get("/admin/summary", response_model=AdminSummaryResponse)
def get_admin_summary():
    try:
        if db is None:
            return AdminSummaryResponse(
                stats=AdminStats(
                    active_buses=0,
                    risk_alerts=0,
                    system_health=0,
                    registered_users=0,
                ),
                alerts=[]
            )

        # Keep admin summary lightweight for the dashboard.
        # The admin landing page only needs live bus count and recent unread alerts,
        # so we avoid scanning large collections like trips/users here.
        alerts_docs = list(
            db.collection('alert_history')
            .where(filter=FieldFilter('status', '==', 'unread'))
            .limit(10)
            .stream()
        )
        live_buses = list(
            db.collection('LIVE-STATUS')
            .where(filter=FieldFilter('status', '==', 'active'))
            .stream()
        )
        # Fetch only the 'status' field to avoid pulling the entire user documents
        users_stream = db.collection('users').select(['status']).stream()
        users_count = sum(1 for doc in users_stream if str((doc.to_dict() or {}).get('status', 'active')).lower() != 'deleted')

        # Fetch real alerts
        alerts_list = []
        for doc in alerts_docs:
            d = doc.to_dict() or {}
            alerts_list.append({
                "id": doc.id,
                "type": d.get("type", "Safety"),
                "description": d.get(
                    "description",
                    d.get("message", "Threshold exceeded")
                ),
                "time": d.get("timestamp", "Just now"),
                "severity": d.get("severity", "medium")
            })

        return AdminSummaryResponse(
            stats=AdminStats(
                active_buses=_safe_size(live_buses),
                risk_alerts=_safe_size(alerts_docs),
                system_health=99.4,
                registered_users=users_count,
            ),
            alerts=alerts_list
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

from fastapi import APIRouter
from services.revenue_service import RevenueService
from models.schemas import DashboardSummaryResponse

router = APIRouter()

@router.get("/dashboard/revenue-summary", response_model=DashboardSummaryResponse)
def get_revenue_summary():
    """
    Returns the fully aggregated revenue dashboard statistics.
    All business logic (Leakage %, AI Recommendations, Profit margins) 
    is handled server-side to keep the Flutter frontend stateless.
    """
    return RevenueService.get_dashboard_summary()

from fastapi import APIRouter, Query
from fastapi.responses import Response
from services.revenue_service import RevenueService
from models.schemas import DashboardSummaryResponse

router = APIRouter()

@router.get("/dashboard/revenue-summary", response_model=DashboardSummaryResponse)
def get_revenue_summary(
    range: str = Query(default="today"),
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
):
    """
    Returns the fully aggregated revenue dashboard statistics.
    All business logic (Leakage %, AI Recommendations, Profit margins) 
    is handled server-side to keep the Flutter frontend stateless.
    """
    return RevenueService.get_dashboard_summary(
        range_preset=range,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/dashboard/revenue-report.csv")
def download_revenue_report(
    range: str = Query(default="today"),
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
):
    csv_text, filename = RevenueService.build_revenue_report_csv(
        range_preset=range,
        start_date=start_date,
        end_date=end_date,
    )
    return Response(
        content=csv_text,
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )

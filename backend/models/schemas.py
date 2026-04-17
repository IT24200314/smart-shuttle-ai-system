from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field, field_validator


UserRole = Literal["student", "driver", "admin"]
UserStatus = Literal["active", "disabled", "deleted"]


class StartTripRequest(BaseModel):
    bus_id: str
    trip_type: str
    driver_id: Optional[str] = None
    driver_email: Optional[str] = None


class EndTripRequest(BaseModel):
    bus_id: str
    trip_type: str
    tickets_75: int
    tickets_100: int
    tickets_150: int
    tickets_200: int


class StopSessionRequest(BaseModel):
    bus_id: str


class DriverBehaviorRequest(BaseModel):
    bus_id: str
    driver_id: str
    event_type: str
    severity: str
    confidence: float


class PassengerLogRequest(BaseModel):
    bus_id: str
    trip_id: str
    detected_count: int


class AuthRegisterRequest(BaseModel):
    email: str = Field(pattern=r"^\S+@\S+\.\S+$")
    password: str = Field(min_length=6)
    role: UserRole
    name: str = Field(min_length=1, max_length=120)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Name cannot be empty")
        return cleaned


class AuthLoginRequest(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        return value.strip().lower()


class UserUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    email: Optional[str] = Field(default=None, pattern=r"^\S+@\S+\.\S+$")
    role: Optional[UserRole] = None
    status: Optional[UserStatus] = None
    password: Optional[str] = Field(default=None, min_length=6)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: Optional[str]) -> Optional[str]:
        return value.strip().lower() if value is not None else value

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: Optional[str]) -> Optional[str]:
        return value.strip() if value is not None else value


class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    role: str
    status: str
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class FeedbackSubmitRequest(BaseModel):
    trip_id: str
    student_id: Optional[str] = None
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = Field(default="", max_length=500)

    @field_validator("trip_id")
    @classmethod
    def normalize_trip_id(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Trip id is required")
        return cleaned

    @field_validator("student_id")
    @classmethod
    def normalize_student_id(cls, value: Optional[str]) -> Optional[str]:
        return value.strip() if value is not None else value

    @field_validator("comment")
    @classmethod
    def normalize_comment(cls, value: Optional[str]) -> str:
        return (value or "").strip()


class FeedbackUpdateRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = Field(default="", max_length=500)

    @field_validator("comment")
    @classmethod
    def normalize_comment(cls, value: Optional[str]) -> str:
        return (value or "").strip()


class FeedbackResponse(BaseModel):
    id: str
    trip_id: str
    student_id: str
    student_name: Optional[str] = None
    rating: int
    comment: str
    created_at: str
    updated_at: str
    trip_type: Optional[str] = None
    trip_status: Optional[str] = None


class FeedbackSummaryResponse(BaseModel):
    average_rating: float
    total_feedback: int
    rating_distribution: Dict[str, int]
    recent_comments: List[FeedbackResponse]


class FeedbackListResponse(BaseModel):
    items: List[FeedbackResponse]
    average_rating: float
    total_feedback: int
    rating_distribution: Dict[str, int]


class TripFeedbackResponse(BaseModel):
    trip_id: str
    trip_type: Optional[str] = None
    trip_status: Optional[str] = None
    average_rating: float
    total_feedback: int
    items: List[FeedbackResponse]


class FeedbackEligibleTripResponse(BaseModel):
    trip_id: str
    trip_type: Optional[str] = None
    trip_status: str
    actual_end_time: Optional[str] = None
    average_rating: float = 0.0
    feedback_count: int = 0


class GPSUpdateRequest(BaseModel):
    bus_id: str
    latitude: float
    longitude: float
    speed: float


class ClaimItemRequest(BaseModel):
    student_id: str
    item_id: str
    otp: Optional[str] = None


class AdminLostFoundActionRequest(BaseModel):
    item_id: str
    admin_id: str


class AIRecommendation(BaseModel):
    morning_action: str
    evening_action: str
    confidence: str
    reason_points: List[str]


class YieldAlert(BaseModel):
    title: str
    last_n_evening_trips: int
    avg_revenue: float
    fixed_cost: float
    avg_loss: float
    recommendation: str
    severity: str


class BestWorstTrip(BaseModel):
    trip_type: str
    profit_or_loss: float
    label: str


class RecentTripItem(BaseModel):
    date: str
    trip_type: str
    ai_passengers: int
    tickets_sold: int
    unpaid_or_leaked: int
    actual_revenue: float
    operating_cost: float
    profit_or_loss: float
    is_profit: bool
    is_warning: bool


class RevenueSummaryData(BaseModel):
    revenue_today: float
    net_profit_today: float
    ticket_leakage_amount: float
    ticket_leakage_percent: float
    trips_done_today: int
    total_ai_passengers: int
    total_tickets_sold: int
    total_unpaid_or_leaked: int
    overall_leakage_rate: float


class SelectedRangeInfo(BaseModel):
    preset: str
    start_date: str
    end_date: str
    label: str


class DailyTrendPoint(BaseModel):
    date: str
    label: str
    tickets_sold: int
    revenue: float
    ai_passengers: int
    unpaid_or_leaked: int
    leakage_percent: float
    profitable_trips: int
    total_trips: int
    morning_total: int
    morning_profitable: int
    evening_total: int
    evening_profitable: int


class PercentageInsight(BaseModel):
    paid_percentage: float
    unpaid_percentage: float
    profitable_trip_percentage: float
    morning_success_percentage: float
    evening_success_percentage: float


class ReportSummary(BaseModel):
    trip_count: int
    tickets_sold: int
    ai_passengers: int
    unpaid_or_leaked: int
    leakage_percentage: float
    total_revenue: float
    total_profit_or_loss: float
    low_demand_trip_count: int
    key_recommendation: str


class ComparisonContext(BaseModel):
    reference_window_label: str
    average_daily_tickets: float
    average_daily_revenue: float
    average_daily_profit: float
    average_daily_leakage_percent: float
    average_daily_trips: float
    selected_period_tickets_delta_percent: float
    selected_period_revenue_delta_percent: float
    selected_period_profit_delta_percent: float
    benchmark_daily_trends: List[DailyTrendPoint]


class DashboardSummaryResponse(BaseModel):
    summary_data: RevenueSummaryData
    ai_recommendation: AIRecommendation
    low_demand_alert: Optional[YieldAlert]
    best_trip: Optional[BestWorstTrip]
    worst_trip: Optional[BestWorstTrip]
    recent_trips: List[RecentTripItem]
    selected_range: SelectedRangeInfo
    daily_trends: List[DailyTrendPoint]
    percentage_insight: PercentageInsight
    report_summary: ReportSummary
    comparison_context: ComparisonContext


class AdminStats(BaseModel):
    active_buses: int
    risk_alerts: int
    system_health: float = 100.0
    registered_users: int = 0


class AdminSummaryResponse(BaseModel):
    stats: AdminStats
    alerts: List[dict]

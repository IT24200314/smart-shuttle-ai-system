from pydantic import BaseModel
from typing import List, Optional

class StartTripRequest(BaseModel):
    bus_id: str
    trip_type: str
    driver_id: Optional[str] = "driver-01"

class EndTripRequest(BaseModel):
    bus_id: str
    trip_type: str
    tickets_75: int
    tickets_100: int
    tickets_150: int
    tickets_200: int

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
    email: str
    password: str
    role: str
    name: str

class AuthLoginRequest(BaseModel):
    email: str
    password: str

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

class DashboardSummaryResponse(BaseModel):
    summary_data: RevenueSummaryData
    ai_recommendation: AIRecommendation
    low_demand_alert: Optional[YieldAlert]
    best_trip: Optional[BestWorstTrip]
    worst_trip: Optional[BestWorstTrip]
    recent_trips: List[RecentTripItem]

class AdminStats(BaseModel):
    active_buses: int
    risk_alerts: int

class AdminSummaryResponse(BaseModel):
    stats: AdminStats
    alerts: List[dict]

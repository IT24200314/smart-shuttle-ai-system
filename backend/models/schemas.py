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

class TripLedgerItem(BaseModel):
    date: str
    tripType: str
    aiCount: int
    ticketsSold: int
    profitOrLoss: float
    isProfit: bool

class BestWorstTrip(BaseModel):
    tripType: str
    profitOrLoss: float

class AIRecommendation(BaseModel):
    morning_action: str
    evening_action: str
    reason: List[str]

class YieldAlert(BaseModel):
    is_active: bool
    avg_revenue: float
    avg_loss: float
    losses_count: int
    total_searched: int

class RevenueSummaryData(BaseModel):
    total_revenue: float
    revenue_growth: float
    forecast_30d: float
    leakage_percent: float
    leakage_amount: float

class RecentTripItem(BaseModel):
    trip_id: str
    route_id: str
    passenger_count: int
    revenue: float

class DashboardSummaryResponse(BaseModel):
    summary: RevenueSummaryData
    recent_trips: List[RecentTripItem]

class AdminStats(BaseModel):
    active_buses: int
    risk_alerts: int

class AdminSummaryResponse(BaseModel):
    stats: AdminStats
    alerts: List[dict]

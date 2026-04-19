from fastapi import APIRouter

from models.schemas import (
    EndTripRequest,
    PassengerLogRequest,
    StartTripRequest,
    StopSessionRequest,
)
from services.driver_session_coordinator import driver_session_coordinator


router = APIRouter()

@router.post("/driver/start-trip")
def start_trip(req: StartTripRequest):
    return driver_session_coordinator.start_trip(req)


@router.post("/driver/stop-session")
def stop_session(req: StopSessionRequest):
    return driver_session_coordinator.stop_session(req)


@router.post("/driver/end-trip")
def end_trip(req: EndTripRequest):
    return driver_session_coordinator.end_trip(req)


@router.get("/driver/safety-score/{driver_email}")
def get_driver_safety_score(driver_email: str):
    return driver_session_coordinator.get_driver_safety_score(driver_email)


@router.post("/driver/passenger-log")
def log_passenger(req: PassengerLogRequest):
    return driver_session_coordinator.log_passenger(req)

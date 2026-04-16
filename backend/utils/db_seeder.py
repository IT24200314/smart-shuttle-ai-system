import argparse
import hashlib
import os
import random
from datetime import date, datetime, time, timedelta

import bcrypt
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter


SEED_TAG = "smart_shuttle_demo_v3"
DEMO_PASSWORD = "password"
DAYS_TO_SEED = 90
FIXED_TRIP_COST = 4000
BASE_NOW = datetime.now().replace(microsecond=0)


ACTIVE_RESET_COLLECTIONS = [
    "users",
    "trips",
    "feedback",
    "passenger_logs",
    "driver_behavior_logs",
    "alert_history",
    "gps_tracking_history",
    "lost_found_items",
    "lost_found_claim_requests",
    "LIVE-STATUS",
    "ticket_prices",
    "admin_settings",
    "bus_routes",
]

LEGACY_COLLECTIONS = [
    "demo_users",
    "demo_trips",
    "demo_feedback",
    "user_profiles",
    "trip_financials",
    "summary_statistics",
    "route_snapshots",
]


key_path = os.path.join(os.path.dirname(__file__), "../database/serviceAccountKey.json")
cred = credentials.Certificate(key_path)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()


def _now_iso() -> str:
    return datetime.now().isoformat()


def _seed_random(*parts: str | int) -> random.Random:
    seed_input = "::".join(str(part) for part in parts)
    return random.Random(seed_input)


def _get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def _feedback_doc_id(trip_id: str, student_id: str) -> str:
    digest = hashlib.sha1(f"{trip_id}::{student_id}".encode("utf-8")).hexdigest()
    return f"FBK-{digest[:12].upper()}"


def _delete_seeded_documents(collection_name: str) -> int:
    deleted = 0
    docs = (
        db.collection(collection_name)
        .where(filter=FieldFilter("seed_source", "==", SEED_TAG))
        .stream()
    )
    for doc in docs:
        doc.reference.delete()
        deleted += 1
    return deleted


def _delete_all_documents(collection_name: str) -> int:
    deleted = 0
    for doc in db.collection(collection_name).stream():
        doc.reference.delete()
        deleted += 1
    return deleted


def reset_demo_database(
    *,
    reset_mode: str = "full",
    delete_legacy: bool = True,
) -> dict[str, dict[str, int]]:
    print("Stage 1: Cleaning demo collections...")
    active_counts: dict[str, int] = {}
    legacy_counts: dict[str, int] = {}

    for collection_name in ACTIVE_RESET_COLLECTIONS:
        deleted = (
            _delete_all_documents(collection_name)
            if reset_mode == "full"
            else _delete_seeded_documents(collection_name)
        )
        active_counts[collection_name] = deleted
        if deleted:
            print(f"  - {collection_name}: removed {deleted} document(s)")

    if delete_legacy:
        print("Stage 1b: Removing legacy demo-only collections...")
        for collection_name in LEGACY_COLLECTIONS:
            deleted = _delete_all_documents(collection_name)
            legacy_counts[collection_name] = deleted
            if deleted:
                print(f"  - {collection_name}: removed {deleted} document(s)")

    print("Cleanup complete.\n")
    return {
        "active": active_counts,
        "legacy": legacy_counts,
    }


def upsert_document(collection_name: str, doc_id: str, payload: dict, counts: dict) -> None:
    db.collection(collection_name).document(doc_id).set(payload)
    counts[collection_name] = counts.get(collection_name, 0) + 1


def seed_core_documents() -> tuple[dict, list[dict]]:
    print("Stage 2: Upserting auth users, routes, settings, and live status...")
    counts: dict[str, int] = {}
    password_hash = _get_password_hash(DEMO_PASSWORD)
    created_at = BASE_NOW.isoformat()

    user_records = [
        {
            "id": "admin-01",
            "email": "admin@shuttle.lk",
            "name": "Mitheja Admin",
            "role": "admin",
            "status": "active",
            "is_primary_admin": True,
        },
        {
            "id": "admin-02",
            "email": "ops.admin@shuttle.lk",
            "name": "Nadeesha Ops",
            "role": "admin",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "driver-01",
            "email": "driver@shuttle.lk",
            "name": "Kamal Perera",
            "role": "driver",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "driver-02",
            "email": "driver2@shuttle.lk",
            "name": "Sahan Jayasuriya",
            "role": "driver",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "driver-03",
            "email": "driver3@shuttle.lk",
            "name": "Ravindu Senanayake",
            "role": "driver",
            "status": "disabled",
            "is_primary_admin": False,
        },
        {
            "id": "student-01",
            "email": "student1@shuttle.lk",
            "name": "Anjali Fernando",
            "role": "student",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "student-02",
            "email": "student2@shuttle.lk",
            "name": "Nipun Hettiarachchi",
            "role": "student",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "student-03",
            "email": "student3@shuttle.lk",
            "name": "Ishara Wijesinghe",
            "role": "student",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "student-04",
            "email": "student4@shuttle.lk",
            "name": "Tharushi Jayawardena",
            "role": "student",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "student-05",
            "email": "student5@shuttle.lk",
            "name": "Kavindu Madushanka",
            "role": "student",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "student-06",
            "email": "student6@shuttle.lk",
            "name": "Dinushi Perera",
            "role": "student",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "student-07",
            "email": "student7@shuttle.lk",
            "name": "Shenal Wickramasinghe",
            "role": "student",
            "status": "active",
            "is_primary_admin": False,
        },
        {
            "id": "student-08",
            "email": "student8@shuttle.lk",
            "name": "Piumi Samarasinghe",
            "role": "student",
            "status": "disabled",
            "is_primary_admin": False,
        },
        {
            "id": "student-09",
            "email": "student9@shuttle.lk",
            "name": "Lahiru Abeysekara",
            "role": "student",
            "status": "deleted",
            "is_primary_admin": False,
        },
    ]

    for user in user_records:
        upsert_document(
            "users",
            user["id"],
            {
                "email": user["email"],
                "name": user["name"],
                "role": user["role"],
                "status": user["status"],
                "password_hash": password_hash,
                "is_primary_admin": user["is_primary_admin"],
                "created_at": created_at,
                "updated_at": created_at,
                "seed_source": SEED_TAG,
            },
            counts,
        )

    upsert_document(
        "ticket_prices",
        "standard_fares",
        {
            "price_75": 75,
            "price_100": 100,
            "price_150": 150,
            "price_200": 200,
            "updatedAt": created_at,
            "seed_source": SEED_TAG,
        },
        counts,
    )

    upsert_document(
        "admin_settings",
        "global_config",
        {
            "operating_cost_per_trip": FIXED_TRIP_COST,
            "leakage_alert_threshold_percent": 10,
            "notifications_enabled": True,
            "seed_source": SEED_TAG,
        },
        counts,
    )

    upsert_document(
        "bus_routes",
        "RT-001",
        {
            "name": "Campus <-> Peradeniya Main",
            "active_buses": ["NB-2341", "NB-4512"],
            "waypoints": [
                {"lat": 7.2544, "lng": 80.5916, "stop_name": "Main Gate"},
                {"lat": 7.2588, "lng": 80.5988, "stop_name": "Library Phase"},
                {"lat": 7.2621, "lng": 80.6010, "stop_name": "Peradeniya Terminal"},
            ],
            "seed_source": SEED_TAG,
        },
        counts,
    )

    upsert_document(
        "bus_routes",
        "RT-002",
        {
            "name": "Campus <-> Kandy City",
            "active_buses": ["NB-7834"],
            "waypoints": [
                {"lat": 7.2906, "lng": 80.6337, "stop_name": "Kandy Clock Tower"},
                {"lat": 7.2748, "lng": 80.6218, "stop_name": "Getambe Junction"},
                {"lat": 7.2544, "lng": 80.5916, "stop_name": "Main Gate"},
            ],
            "seed_source": SEED_TAG,
        },
        counts,
    )

    for bus_id, latitude, longitude in [
        ("NB-2341", 7.2551, 80.5922),
        ("NB-4512", 7.2604, 80.6008),
        ("NB-7834", 7.2728, 80.6203),
    ]:
        upsert_document(
            "LIVE-STATUS",
            bus_id,
            {
                "latitude": latitude,
                "longitude": longitude,
                "speed": 0,
                "status": "idle",
                "tripType": None,
                "trip_id": None,
                "driver_id": None,
                "passenger_count": 0,
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
                "estimated_passenger_count": 0,
                "ai_state": "idle",
                "last_updated": created_at,
                "seed_source": SEED_TAG,
            },
            counts,
        )

    return counts, user_records


def _weighted_split(total: int, weights: list[int]) -> list[int]:
    if total <= 0:
        return [0 for _ in weights]

    total_weight = sum(weights)
    raw_values = [total * weight / total_weight for weight in weights]
    values = [int(value) for value in raw_values]
    remainder = total - sum(values)
    indexed_remainders = sorted(
        enumerate(raw_values),
        key=lambda item: (item[1] - int(item[1]), -item[0]),
        reverse=True,
    )
    for index, _ in indexed_remainders[:remainder]:
        values[index] += 1
    return values


def _ticket_mix(sold_tickets: int, trip_type: str, weekday: int) -> dict[str, int]:
    if trip_type == "Morning":
        weights = [48, 30, 14, 8] if weekday < 5 else [55, 25, 12, 8]
    else:
        weights = [58, 26, 11, 5] if weekday < 5 else [65, 22, 9, 4]

    tickets_75, tickets_100, tickets_150, tickets_200 = _weighted_split(sold_tickets, weights)
    return {
        "tickets_75": tickets_75,
        "tickets_100": tickets_100,
        "tickets_150": tickets_150,
        "tickets_200": tickets_200,
    }


def _trip_times(trip_date: date, trip_type: str, rng: random.Random) -> tuple[datetime, datetime]:
    if trip_type == "Morning":
        start_hour = 6
        start_minute = 45 + rng.randint(0, 25)
        duration_minutes = 46 + rng.randint(0, 18)
    else:
        start_hour = 16
        start_minute = 55 + rng.randint(0, 35)
        duration_minutes = 52 + rng.randint(0, 22)

    start_time = datetime.combine(trip_date, time(hour=start_hour, minute=0)) + timedelta(
        minutes=start_minute
    )
    end_time = start_time + timedelta(minutes=duration_minutes)
    return start_time, end_time


def _feedback_templates(ride_quality: str) -> list[tuple[int, str]]:
    if ride_quality == "great":
        return [
            (5, "Smooth ride and we reached campus on time."),
            (5, "Very comfortable trip and the bus was clean."),
            (4, "Good service overall. Boarding was quick and organized."),
            (4, "Ride was pleasant with enough space for most students."),
        ]
    if ride_quality == "mixed":
        return [
            (4, "The trip was okay, but it got crowded near the last stop."),
            (3, "Reached safely, though the evening traffic caused a delay."),
            (4, "Clean bus, but the waiting time felt a little long."),
            (3, "No major issues, just a slightly cramped ride."),
        ]
    return [
        (2, "The bus was too crowded and arrived later than expected."),
        (1, "Very uncomfortable trip. There was heavy crowding throughout."),
        (2, "Delay was noticeable and there were not enough seats available."),
        (3, "Trip was manageable, but boarding was chaotic today."),
    ]


def _build_feedback_records(
    *,
    trip_id: str,
    trip_type: str,
    trip_status: str,
    ride_quality: str,
    candidate_students: list[str],
) -> list[dict]:
    rng = _seed_random("feedback", trip_id)
    templates = _feedback_templates(ride_quality)
    feedback_count = 2 if ride_quality == "bad" else 3 if ride_quality == "mixed" else 4
    selected_templates = templates[:feedback_count]
    selected_students = rng.sample(candidate_students, k=feedback_count)

    records = []
    for index, (rating, comment) in enumerate(selected_templates):
        student_id = selected_students[index]
        records.append(
            {
                "id": _feedback_doc_id(trip_id, student_id),
                "trip_id": trip_id,
                "student_id": student_id,
                "student_name": student_id.replace("-", " ").title(),
                "rating": rating,
                "comment": comment,
                "trip_type": trip_type,
                "trip_status": trip_status,
            }
        )
    return records


def _demand_profiles(day_offset: int, weekday: int, rng: random.Random) -> list[dict]:
    is_weekend = weekday >= 5
    weekend_penalty = 16 if weekday == 5 else 24 if weekday == 6 else 0
    term_wave = 6 if day_offset % 21 < 7 else -4 if day_offset % 21 > 16 else 1
    weather_penalty = 8 if day_offset % 17 == 0 else 0
    campus_event_bonus = 5 if weekday in {0, 2} and day_offset % 11 == 0 else 0

    morning_ai = max(
        22,
        68
        - weekend_penalty
        + term_wave
        - weather_penalty
        + campus_event_bonus
        + rng.randint(-5, 6),
    )
    evening_ai = max(
        10,
        38
        - (weekend_penalty + 8 if is_weekend else 0)
        + (term_wave // 2)
        - weather_penalty
        + rng.randint(-6, 5),
    )

    critical_evening = weekday in {4, 5, 6} or day_offset % 9 == 0
    morning_leakage = min(0.12, 0.04 + ((day_offset + weekday) % 4) * 0.015)
    evening_leakage = 0.11 + ((day_offset + weekday) % 5) * 0.025
    if critical_evening:
        evening_leakage += 0.08
    evening_leakage = min(evening_leakage, 0.34)

    morning_sold = max(int(round(morning_ai * (1 - morning_leakage))), max(18, morning_ai - 8))
    evening_sold = max(int(round(evening_ai * (1 - evening_leakage))), 4)
    evening_sold = min(evening_sold, evening_ai)

    return [
        {
            "segment": "M",
            "trip_type": "Morning",
            "ai_passengers": morning_ai,
            "sold_tickets": min(morning_sold, morning_ai),
        },
        {
            "segment": "E",
            "trip_type": "Evening",
            "ai_passengers": evening_ai,
            "sold_tickets": min(evening_sold, evening_ai),
        },
    ]


def seed_operational_history(days_to_seed: int = DAYS_TO_SEED) -> dict[str, int]:
    print(f"Stage 3: Seeding {days_to_seed} days of realistic trips, feedback, and telemetry...")
    counts: dict[str, int] = {}

    buses = ["NB-2341", "NB-4512", "NB-7834"]
    drivers = ["driver-01", "driver-02"]
    active_students = [
        "student-01",
        "student-02",
        "student-03",
        "student-04",
        "student-05",
        "student-06",
        "student-07",
    ]
    lost_items = [
        "Black Backpack",
        "Umbrella",
        "Laptop Sleeve",
        "Water Bottle",
        "Student ID Card",
        "Jacket",
    ]

    for day_offset in range(days_to_seed - 1, -1, -1):
        trip_date = (BASE_NOW - timedelta(days=day_offset)).date()
        date_str = trip_date.isoformat()
        weekday = trip_date.weekday()
        day_rng = _seed_random("day", date_str)
        profiles = _demand_profiles(day_offset, weekday, day_rng)

        for trip_index, profile in enumerate(profiles):
            trip_type = profile["trip_type"]
            segment = profile["segment"]
            ai_passengers = profile["ai_passengers"]
            sold_tickets = profile["sold_tickets"]
            unpaid = max(ai_passengers - sold_tickets, 0)
            bus_id = buses[(day_offset + trip_index) % len(buses)]
            driver_id = drivers[(day_offset + trip_index) % len(drivers)]
            trip_id = f"SEED-TRIP-{trip_date.strftime('%Y%m%d')}-{segment}"

            trip_rng = _seed_random(trip_id)
            ticket_mix = _ticket_mix(sold_tickets, trip_type, weekday)
            actual_revenue = (
                ticket_mix["tickets_75"] * 75
                + ticket_mix["tickets_100"] * 100
                + ticket_mix["tickets_150"] * 150
                + ticket_mix["tickets_200"] * 200
            )
            avg_fare = (actual_revenue / sold_tickets) if sold_tickets > 0 else 0.0
            revenue_leakage = round(unpaid * avg_fare, 2)
            profit_or_loss = round(actual_revenue - FIXED_TRIP_COST, 2)

            if profit_or_loss >= 800 and unpaid <= 4:
                ride_quality = "great"
            elif profit_or_loss >= -900 and unpaid <= 9:
                ride_quality = "mixed"
            else:
                ride_quality = "bad"

            start_time, end_time = _trip_times(trip_date, trip_type, trip_rng)
            feedback_records = _build_feedback_records(
                trip_id=trip_id,
                trip_type=trip_type,
                trip_status="completed",
                ride_quality=ride_quality,
                candidate_students=active_students,
            )
            average_rating = round(
                sum(record["rating"] for record in feedback_records) / len(feedback_records),
                2,
            )

            upsert_document(
                "trips",
                trip_id,
                {
                    "date": date_str,
                    "tripType": trip_type,
                    "status": "completed",
                    "driverId": driver_id,
                    "busId": bus_id,
                    "actualStartTime": start_time.isoformat(),
                    "actualEndTime": end_time.isoformat(),
                    "aiPassengerCount": ai_passengers,
                    "estimatedPassengerCount": ai_passengers,
                    "finalEstimatedPassengerCount": ai_passengers,
                    "liveEstimatedPassengerCountAtEnd": ai_passengers,
                    "soldTicketCount": sold_tickets,
                    "unpaidPassengerCount": unpaid,
                    "actualRevenue": actual_revenue,
                    "revenueLeakage": revenue_leakage,
                    "fixedCost": FIXED_TRIP_COST,
                    "profitOrLoss": profit_or_loss,
                    "feedbackCount": len(feedback_records),
                    "averageRating": average_rating,
                    "tickets_75": ticket_mix["tickets_75"],
                    "tickets_100": ticket_mix["tickets_100"],
                    "tickets_150": ticket_mix["tickets_150"],
                    "tickets_200": ticket_mix["tickets_200"],
                    "created_at": start_time.isoformat(),
                    "updated_at": end_time.isoformat(),
                    "seed_source": SEED_TAG,
                },
                counts,
            )

            for log_index, detected_ratio in enumerate((0.42, 0.76, 1.0), start=1):
                detected_count = max(1, min(ai_passengers, int(round(ai_passengers * detected_ratio))))
                log_timestamp = start_time + timedelta(minutes=log_index * 15)
                upsert_document(
                    "passenger_logs",
                    f"SEED-PLOG-{trip_date.strftime('%Y%m%d')}-{segment}-{log_index}",
                    {
                        "bus_id": bus_id,
                        "trip_id": trip_id,
                        "detected_count": detected_count,
                        "timestamp": log_timestamp.isoformat(),
                        "seed_source": SEED_TAG,
                    },
                    counts,
                )

            for feedback_index, feedback_record in enumerate(feedback_records, start=1):
                comment_time = end_time + timedelta(minutes=8 + feedback_index * 6)
                upsert_document(
                    "feedback",
                    feedback_record["id"],
                    {
                        "feedback_id": feedback_record["id"],
                        "trip_id": feedback_record["trip_id"],
                        "student_id": feedback_record["student_id"],
                        "student_name": feedback_record["student_name"],
                        "rating": feedback_record["rating"],
                        "comment": feedback_record["comment"],
                        "trip_type": feedback_record["trip_type"],
                        "trip_status": feedback_record["trip_status"],
                        "created_at": comment_time.isoformat(),
                        "updated_at": comment_time.isoformat(),
                        "seed_source": SEED_TAG,
                    },
                    counts,
                )

            should_raise_leakage_alert = trip_type == "Evening" and unpaid >= 8
            should_raise_low_demand_alert = sold_tickets <= 18 or profit_or_loss < -1700
            if should_raise_leakage_alert or should_raise_low_demand_alert:
                alert_type = "Revenue Leakage" if should_raise_leakage_alert else "Low Demand"
                alert_severity = "high" if unpaid >= 12 or profit_or_loss < -2200 else "medium"
                alert_status = "unread" if day_offset <= 2 else "resolved"
                alert_description = (
                    f"High evening leakage detected on {date_str}"
                    if should_raise_leakage_alert
                    else f"Low-demand {trip_type.lower()} trip detected on {date_str}"
                )
                upsert_document(
                    "alert_history",
                    f"SEED-ALERT-{trip_date.strftime('%Y%m%d')}-{segment}",
                    {
                        "bus_id": bus_id,
                        "driver_id": driver_id,
                        "type": alert_type,
                        "description": alert_description,
                        "status": alert_status,
                        "severity": alert_severity,
                        "timestamp": end_time.isoformat(),
                        "seed_source": SEED_TAG,
                    },
                    counts,
                )

        if day_offset < 14:
            for point_index in range(3):
                gps_time = datetime.combine(trip_date, time(hour=6 + point_index * 5, minute=20))
                upsert_document(
                    "gps_tracking_history",
                    f"SEED-GPS-{trip_date.strftime('%Y%m%d')}-{point_index + 1}",
                    {
                        "bus_id": buses[(day_offset + point_index) % len(buses)],
                        "latitude": round(7.245 + (day_offset * 0.0018) + (point_index * 0.0045), 6),
                        "longitude": round(80.585 + (day_offset * 0.0012) + (point_index * 0.0038), 6),
                        "speed": 18 + (point_index * 7) + (day_offset % 4),
                        "timestamp": gps_time.isoformat(),
                        "seed_source": SEED_TAG,
                    },
                    counts,
                )

        if day_offset % 12 == 0:
            item_id = f"SEED-LF-{trip_date.strftime('%Y%m%d')}"
            item_status = "verified" if day_offset % 24 == 0 else "claimRequested"
            upsert_document(
                "lost_found_items",
                item_id,
                {
                    "type": lost_items[(day_offset // 3) % len(lost_items)],
                    "date_found": date_str,
                    "status": item_status,
                    "busId": buses[day_offset % len(buses)],
                    "claimedBy": "student-01",
                    "verifiedBy": "admin-01" if item_status == "verified" else None,
                    "seed_source": SEED_TAG,
                },
                counts,
            )
            upsert_document(
                "lost_found_claim_requests",
                f"SEED-CLM-{trip_date.strftime('%Y%m%d')}",
                {
                    "item_id": item_id,
                    "student_id": "student-01",
                    "timestamp": datetime.combine(trip_date, time(hour=18, minute=15)).isoformat(),
                    "status": "approved" if item_status == "verified" else "pending_verification",
                    "seed_source": SEED_TAG,
                },
                counts,
            )

        for driver_index, driver_email in enumerate(["driver@shuttle.lk", "driver2@shuttle.lk"]):
            safety_rng = _seed_random("safety", driver_email, date_str)
            yawn_count = safety_rng.randint(0, 2 if weekday < 5 else 3)
            phone_count = 1 if (day_offset + driver_index) % 17 == 0 else 0
            drowsiness_count = 1 if (day_offset + driver_index) % 29 == 0 else 0
            safety_score = max(72, 100 - (yawn_count * 4) - (phone_count * 9) - (drowsiness_count * 12))

            upsert_document(
                "driver_behavior_logs",
                f"{driver_email}_{date_str}",
                {
                    "email": driver_email,
                    "date": date_str,
                    "number_of_ywan": yawn_count,
                    "number_of_usephone": phone_count,
                    "number_of_drowsiness": drowsiness_count,
                    "safety_score": safety_score,
                    "session_active": False,
                    "seed_source": SEED_TAG,
                },
                counts,
            )

    return counts


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Safely reset and seed the Smart Shuttle demo Firestore database."
    )
    parser.add_argument(
        "--reset-mode",
        choices=["tagged", "full"],
        default="full",
        help="Use 'full' for a clean demo database, or 'tagged' to remove only current seeded documents.",
    )
    parser.add_argument(
        "--delete-legacy",
        action="store_true",
        default=True,
        help="Delete documents inside known legacy demo collections.",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=DAYS_TO_SEED,
        help="Number of days of realistic operational history to generate.",
    )
    args = parser.parse_args()

    if args.days < 1:
        raise ValueError("The seeder must generate at least one day of demo data.")

    print("=" * 64)
    print("SMART SHUTTLE AI - CLEAN DEMO RESEED")
    print("=" * 64)
    print(f"Seed source tag: {SEED_TAG}")
    print(f"Reset mode: {args.reset_mode}")
    print(f"Legacy cleanup enabled: {args.delete_legacy}")
    print(f"Operational history window: {args.days} days\n")

    cleanup_counts = reset_demo_database(
        reset_mode=args.reset_mode,
        delete_legacy=args.delete_legacy,
    )
    core_counts, users = seed_core_documents()
    ops_counts = seed_operational_history(days_to_seed=args.days)

    print("\n" + "=" * 64)
    print("SEED REPORT")
    print("=" * 64)
    print("Cleanup summary:")
    for scope, scope_counts in cleanup_counts.items():
        if not scope_counts:
            continue
        print(f"  {scope}:")
        for collection_name, count in scope_counts.items():
            print(f"    - {collection_name}: removed {count}")

    print(f"\nSeeded credentials (email + shared password: '{DEMO_PASSWORD}'):")
    for user in users:
        status_suffix = ""
        if user["status"] != "active":
            status_suffix = f" [{user['status']}]"
        print(
            f"  - {user['email']} -> role={user['role']}, "
            f"status={user['status']}{status_suffix}"
        )

    print("\nInserted / updated counts:")
    final_counts = {**core_counts}
    for collection_name, count in ops_counts.items():
        final_counts[collection_name] = final_counts.get(collection_name, 0) + count
    for collection_name, count in final_counts.items():
        print(f"  - {collection_name}: {count}")

    print("\nSeeder complete. Firestore now contains a clean 90-day demo dataset.")
    print("=" * 64)


if __name__ == "__main__":
    main()

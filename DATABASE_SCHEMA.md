# Smart Shuttle AI - Database Schema

The project keeps Flutter as a thin UI client while FastAPI owns the business rules and Firestore document lifecycle.

## `users`
Document id: `user_id`

Core fields:
- `email`
- `name`
- `role` (`student`, `driver`, `admin`)
- `status` (`active`, `disabled`, `deleted`)
- `password_hash`
- `is_primary_admin`
- `created_at`
- `updated_at`
- `last_login_at`
- `seed_source` for seeded demo records

Notes:
- User records are soft-managed through the `status` field.
- The primary admin record is protected from disable/delete flows.
- Auth routes remain compatible with the existing `/auth/register` and `/auth/login` endpoints.

## `trips`
Document id: `trip_id`

Core fields:
- `date`
- `tripType`
- `status` (`active`, `completed`)
- `driverId`
- `busId`
- `actualStartTime`
- `actualEndTime`
- `aiPassengerCount`
- `soldTicketCount`
- `unpaidPassengerCount`
- `actualRevenue`
- `revenueLeakage`
- `fixedCost`
- `profitOrLoss`
- `feedbackCount`
- `averageRating`
- `lastFeedbackAt`
- `created_at`
- `updated_at`
- `seed_source`

Notes:
- A trip document is now created at `POST /driver/start-trip`.
- The same trip is finalized at `POST /driver/end-trip`.
- Revenue reporting should use only `status=completed` trips.

## `feedback`
Document id: deterministic `feedback_id` per `trip_id + student_id`

Core fields:
- `feedback_id`
- `trip_id`
- `student_id`
- `student_name`
- `rating`
- `comment`
- `trip_type`
- `trip_status`
- `created_at`
- `updated_at`
- `seed_source`

Rules:
- One student can only own one feedback record per trip.
- Re-submitting feedback for the same trip updates the existing record.
- `trip_id` creates the trip-to-feedback relationship.
- Trip aggregates are denormalized back into `trips.feedbackCount` and `trips.averageRating`.

## `LIVE-STATUS`
Document id: `bus_id`

Core fields:
- `status`
- `tripType`
- `trip_id`
- `latitude`
- `longitude`
- `speed`
- `passenger_count`
- `current_detected_count`
- `started_at`
- `driver_id`
- `last_updated`
- `seed_source`

Notes:
- Student feedback UI reads `trip_id` from the active live-status payload.
- Driver start/end flow is the source of truth for active trip state.

## `passenger_logs`
Document id: log id

Core fields:
- `bus_id`
- `trip_id`
- `detected_count`
- `timestamp`
- `seed_source`

## `driver_behavior_logs`
Document id: per-driver per-day id

Core fields:
- `email`
- `date`
- `number_of_ywan`
- `number_of_usephone`
- `number_of_drowsiness`
- `safety_score`
- `session_active`
- `seed_source`

## `alert_history`
Document id: alert id

Core fields:
- `bus_id`
- `driver_id`
- `type`
- `description`
- `status`
- `severity`
- `timestamp`
- `seed_source`

## `bus_routes`
Document id: route id

Core fields:
- `name`
- `active_buses`
- `waypoints`
- `seed_source`

## `ticket_prices`
Document id: `standard_fares`

Core fields:
- `price_75`
- `price_100`
- `price_150`
- `price_200`
- `updatedAt`
- `seed_source`

## `admin_settings`
Document id: `global_config`

Core fields:
- `operating_cost_per_trip`
- `leakage_alert_threshold_percent`
- `notifications_enabled`
- `seed_source`

## `lost_found_items`
Document id: item id

Core fields:
- `type`
- `date_found`
- `status`
- `busId`
- `claimedBy`
- `verifiedBy`
- `seed_source`

## `lost_found_claim_requests`
Document id: request id

Core fields:
- `item_id`
- `student_id`
- `timestamp`
- `status`
- `seed_source`

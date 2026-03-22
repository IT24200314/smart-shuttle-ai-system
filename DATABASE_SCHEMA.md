# Smart Shuttle AI — Database Schema
A NoSQL Firestore architecture normalized and rigorously typed by Python Pydantic models.

### 1. `users` (Active Authentication Layer)
**Structure:** `email` (PK), `name` (String), `role` (Enum: admin, student, driver), `password_hash` (Bcrypt String), `status` (String)

### 2. `trips` & `passenger_logs` (Telemetry Hub)
**trips:** `date`, `tripType`, `aiPassengerCount` (YOLO integers), `soldTicketCount`, `revenueLeakage`, `profitOrLoss`, `actualRevenue`, `fixedCost`.
**passenger_logs:** Individual array tracking `detected_count` linked directly to a `trip_id`.
**ticket_prices:** Configuration array (`price_75`, `price_100`) fetched dynamically by Python to ensure Flutter clients cannot tamper with prices.

### 3. `bus_routes` & `LIVE-STATUS` & `gps_tracking_history`
**LIVE-STATUS:** Represents the currently transmitting location block (`latitude`, `longitude`, `speed`) polled natively by the Flutter Thick Client.
**gps_tracking_history:** Appends a historical snapshot of coordinates anytime a `POST /gps/update-location` pulse occurs. 

### 4. `driver_behavior_logs` & `alert_history`
Generated solely by AI computer-vision pipelines.
**alert_history:** Tracked issues like Micro-Sleep Drowsiness mapping to `unread`, rendering directly on `admin_dashboard_screen.dart`.

### 5. `lost_found_items` & `lost_found_claim_requests`
**lost_found_items:** Physical rack items auto-identified. Status rotates: `pending` -> `claimRequested` -> `verified` -> `claimed`.
**lost_found_claim_requests:** Foreign-key ledger mapping student profiles to item requests before Admin Handover execution.

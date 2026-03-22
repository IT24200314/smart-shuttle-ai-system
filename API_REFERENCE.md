# Smart Shuttle AI — Backend API Reference

Base Address: `http://127.0.0.1:8000/` (or `http://10.0.2.2:8000/` in Android Emulator).

## Core API & Analytics (Revenue)
**Endpoint**: `GET /dashboard/revenue-summary`
- **Purpose**: Compute high-level operational leakage and P/L metrics dynamically without thick-client algorithms.
- **Request Body**: None.
- **Response**:
```json
{
  "total_revenue_today": 8450,
  "net_profit_status": "Profit + 12.4%",
  "total_leakage_amount": 1650,
  "leakage_percentage": "13.8%",
  "trips_completed": 7,
  "best_trip": "TRP-Morning-02 (23.4% Margin)",
  "worst_trip": "TRP-Evening-01 (Loss -14%)"
}
```

## Transport Telemetry (Maps)
**Endpoint**: `GET /map/routes`
- **Purpose**: Organically discover bus networks.
**Endpoint**: `POST /gps/update-location`
- **Purpose**: Driver telemetry heartbeat updater.

## Lost & Found Intelligence
**Endpoint**: `GET /lost-found/items`
- **Purpose**: Retrieves all dynamically logged objects from the YOLO vision detection module that are left behind on the shuttle racks.

## Authentication (RBAC)
**Endpoint**: `POST /auth/login`
- **Purpose**: Identifies whether the student/admin/driver trying to access the Flutter app is allowed entry to the desired gateway. 
- **Request**: `{"email": "...", "password": "..."}`
- **Response**: `{"token": "JWT...", "role": "admin"}`

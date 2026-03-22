# Smart Shuttle AI - Project Structure

## Architectural Paradigm
The Smart Shuttle AI system implements a strict **Multi-Tier API Architecture**, permanently decoupling the Flutter mobile thick-client from direct database interactions.

### 1. The Presentation Tier (Frontend — Flutter / Dart)
Located in `frontend/smart_shuttle_app/`.
Flutter serves strictly as the UI rendering engine and API consumer.
**Key constraint:** No Flutter file natively imports `cloud_firestore` to process revenue algorithms or driver behaviors.
- **`screens/admin/`**: Mitheja's Analytics & Dashboard APIs.
- **`screens/driver/`**: Operational ticket inputs triggering `POST /driver/end-trip`.
- **`screens/student/`**: Shamal's Live Map & Rishani's Lost & Found interfaces.
- **`screens/auth/`**: Kaveesha's Role-Based Access Control logic (RBAC).

### 2. The Logic & Integration Tier (Backend — Python FastAPI)
Located in `backend/`.
Python operates as the central authority. All math, AI metric aggregations, Break-even validations, and Database Write locks occur here.
- **`main.py`**: Uvicorn ASGI server entrypoint and router mount.
- **`routes/`**: Distinct API endpoints mapped identically to student team responsibilities.
- **`services/revenue_service.py`**: Heaviest algorithmic file; computes leakage metrics, historical ledger yields, and AI Recommendations safely server-side.
- **`models/schemas.py`**: Pydantic typed enforcement.

### 3. The Data Tier (Cloud Firestore over Firebase Admin SDK)
The backend exclusively manipulates the database using the internal `serviceAccountKey.json` bypass. The databases (`trip_financials`, `users`, `lost_found_items`) are inaccessible to the public domain unless queried through a valid Python endpoint.

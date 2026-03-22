# Smart Shuttle AI — Known Limitations

## 1. Authentication Tokens
- **Current State:** The Auth API handles login queries and role mappings accurately out of Firestore.
- **Limitation:** JSON Web Tokens (JWT) inside `main.py` are strictly mock-ups (e.g. `"dummy-jwt-token"`). 
- **Future Integration:** Implement `python-jose` and OAuth-2 password bearer dependencies across the endpoints so the Flutter client must attach `Authorization: Bearer <token>` in its `http.get()` wrappers.

## 2. Vision Models (YOLO) Integration
- **Current State:** The backend schema features fully compliant slots for passenger arrays (`aiPassengerCount`).
- **Limitation:** The current system relies on manual simulation injection (`db_seeder.py`) for the counts instead of a direct Raspberry Pi hardware payload stream.
- **Future Integration:** Connect the edge-computing cameras directly to the `POST /driver/end-trip` parameter hook via hardware bridges, rather than letting the Driver simulate it.

## 3. Bus Telemetry
- **Current State:** Flutter handles map tracking gracefully.
- **Limitation:** The UI relies on hardcoded path waypoints using Flutter animations because Google Maps Platform billing limits prevented deploying native maps across testing devices.
- **Future Integration:** Swap the `AnimatedBuilder` dots for the official `google_maps_flutter` package.

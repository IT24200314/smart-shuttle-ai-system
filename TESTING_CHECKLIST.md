# Smart Shuttle AI — System Testing Checklist

## 1. Authentication Module (Kaveesha)
- [ ] Attempt to login as `admin@shuttle.lk` -> verify transit to Admin Dashboard.
- [ ] Attempt to login as `driver@shuttle.lk` -> verify transit to Driver Dispatch.
- [ ] Attempt to login as `student@shuttle.lk` -> verify transit to Map Interface.
- [ ] Attempt invalid credentials -> verify Python API throws native exception displayed as SnackBar.

## 2. Telemetry & Maps (Shamal)
- [ ] Ensure the Dropdown organically fetches routes from `http://10.0.2.2:8000/map/routes`.
- [ ] (Future) Ensure the Map dynamically drops a marker on GPS coordinates broadcasted by Driver App.

## 3. Financial Module & Revenue Leakage (Oshada)
- [ ] Submit a new trip from Driver interface with values (`AI=50`, `Tickets Sold=40`).
- [ ] Switch to Admin Dashboard.
- [ ] Verify the **Leakage Amount** accurately reflects the `(50 - 40) * 75 LKR` anomaly.
- [ ] Ensure the Break-Even line correctly tracks at the `4000` LKR operating cost.
- [ ] Verify that Python server rejects the request if the `aiPassengerCount` is omitted.

## 4. Lost & Found Center (Rishani)
- [ ] Seed a new array of dropped object metadata inside Firestore.
- [ ] Verify `GET /lost-found/items` renders `Pending` statuses for the admin interface.
- [ ] Press "Claim" on Student Interface -> Ensure it triggers `POST /lost-found/claim`, swapping Firestore value.

## 5. System Health Flags (Mitheja)
- [ ] Verify the Admin Home screen displays exact quantities of users registered directly populated from the backend.

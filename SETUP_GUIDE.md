# Smart Shuttle AI — Setup Guide

## 1. Prerequisites
- **Python 3.10+** (With a virtual environment setup)
- **Flutter SDK 3.13+** (Windows/Android/iOS toolchain)
- **Firebase Project** (Firestore configured)
- `serviceAccountKey.json` from Firebase Settings (placed identically inside `/backend/utils/` and `/ai_models/passenger_counting/`)

## 2. Setting Up the Backend (Python FastAPI)
1. Open terminal and navigate to: `cd /backend`
2. Install dependencies: `pip install -r requirements.txt`
3. Launch the server locally (or on a remote instance):
   `python -m uvicorn main:app --port 8000 --reload`
4. Verify by browsing to `http://127.0.0.1:8000/health` (should return `"status": "ok"`).

## 3. Seeding the Database (Demo Prep)
1. While inside `/backend/utils/` (with Uvicorn running or stopped):
2. Ensure Firebase references match.
3. Run `python db_seeder.py`
4. This script strictly wipes old analytics and replaces it with live testing ledgers, lost & found logs, map instances, and role privileges for the demo flow.

## 4. Running the Flutter App
1. Ensure the Python API is completely booted. (For Android Emulator, `http://10.0.2.2:8000/` intercepts naturally).
2. Navigate to: `cd /frontend/smart_shuttle_app`
3. Execute `flutter pub get`
4. Run the debugger: `flutter run`
5. At the Login Screen, type `student@shuttle.lk` or `admin@shuttle.lk` or `driver@shuttle.lk` to organically traverse the role boundaries returned by `POST /auth/login`.

# Smart Shuttle AI — Setup Guide

## 1. Prerequisites
- **Python 3.10+** (With a virtual environment setup)
- **Flutter SDK 3.13+** (Windows/Android/iOS toolchain)
- **Firebase Project** (Firestore configured)
- Canonical Firebase manifest: `frontend/smart_shuttle_app/assets/config/firebase_project_manifest.json`
- Canonical Firebase project ID: `smart-shuttle-ai-b58f8`
- Backend Firebase admin key:
  - Preferred: `backend/database/serviceAccountKey.local.json`
  - Or set `SMART_SHUTTLE_FIREBASE_SERVICE_ACCOUNT` to an absolute path
- Example template only: `backend/database/serviceAccountKey.example.json`
- `backend/database/serviceAccountKey.json` is intentionally unsupported and ignored to prevent config drift.

## 2. Safe Firebase Update Workflow
1. Decide the single Firebase project for the whole repo.
2. Update `frontend/smart_shuttle_app/assets/config/firebase_project_manifest.json` first.
3. Regenerate or update:
   - `frontend/smart_shuttle_app/lib/firebase_options.dart`
   - `frontend/smart_shuttle_app/android/app/google-services.json`
4. Replace the backend admin credential with a key from the same project using:
   - `backend/database/serviceAccountKey.local.json`, or
   - `SMART_SHUTTLE_FIREBASE_SERVICE_ACCOUNT`
   Rename freshly downloaded backend keys to `serviceAccountKey.local.json` before local use.
5. Do not commit backup Firebase files such as `google-services (1).json` or a raw `serviceAccountKey.json`.
6. Run `python scripts/verify_firebase_consistency.py`.
7. Only start FastAPI or Flutter after the verification script reports no mismatches.

## 3. Setting Up the Backend (Python FastAPI)
1. Open terminal and navigate to: `cd /backend`
2. Install dependencies: `pip install -r requirements.txt`
3. Launch the server locally (or on a remote instance):
   `python -m uvicorn main:app --port 8000 --reload`
4. Verify by browsing to `http://127.0.0.1:8000/health` (should return `"status": "ok"`).

## 4. Seeding the Database (Demo Prep)
1. While inside `/backend/utils/` (with Uvicorn running or stopped):
2. Ensure Firebase references match.
3. Run `python db_seeder.py`
4. This script strictly wipes old analytics and replaces it with live testing ledgers, lost & found logs, map instances, and role privileges for the demo flow.

## 5. Running the Flutter App
1. Ensure the Python API is completely booted. (For Android Emulator, `http://10.0.2.2:8000/` intercepts naturally).
2. Navigate to: `cd /frontend/smart_shuttle_app`
3. Execute `flutter pub get`
4. Run the debugger: `flutter run`
5. At the Login Screen, type `student@shuttle.lk` or `admin@shuttle.lk` or `driver@shuttle.lk` to organically traverse the role boundaries returned by `POST /auth/login`.

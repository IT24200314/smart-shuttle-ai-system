# Smart Shuttle AI System 🚌✨

Smart Shuttle is a comprehensive, AI-powered university transport management system. It integrates computer vision models, a real-time database, and a cross-platform Flutter application to provide seamless experiences for students, drivers, and administrators. 

---

## 🌟 Key Features

### 1. 🧑‍🎓 Student Mobile App
- **Live Bus Tracking:** See buses approaching on a live map.
- **Crowd Density Estimation:** AI-powered estimates of bus crowdedness (Empty, Normal, Crowded).
- **ETA Predictions:** Real-time arrival predictions using distance matrices.

### 2. 🚦 Driver Mobile App
- **Safety Alerts:** Real-time monitoring for driver fatigue or distraction.
- **Live Route Guidance:** Displays the upcoming stops, traffic conditions, and ETA.
- **Capacity Management:** Driver can see AI passenger counts to ensure safe capacity limits.

### 3. 📊 Admin Web Dashboard
- **AI-Powered Revenue Forecasting:** A 30-day forecasted profit model using advanced charting.
- **Live Fleet Tracking:** Monitor all active buses, passenger counts, and trip efficiency.
- **Data-Driven Insights:** Demand analysis per hour allowing optimized bus scheduling.

### 4. 🤖 AI Vision Models (Python)
- **Passenger Counting (YOLOv11):** Detects passengers boarding/alighting in real-time, calculates estimated revenue, and pushes live states to Firebase Firestore.
- **Driver Behavior Monitoring:** Future integration for spotting driver fatigue/distraction.

---

## 📁 Project Structure

```text
smart-shuttle-ai-system/
├── ai_models/              # Python: YOLOv11 & other AI inference scripts
│   ├── passenger_counting/ # Passenger detection & Firebase integration
│   └── driver_behavior/    # Driver safety monitoring logic
├── backend/                # Backend API & Database configs
│   └── database/           # serviceAccountKey.json for Firebase Admin SDK
├── frontend/               # Flutter cross-platform applications UI
│   └── smart_shuttle_app/  # Main Flutter app (Student, Driver, Admin)
├── analytics/              # Data analysis & forecasting models
└── preprocessing/          # Data cleaning for AI model training
```

---

## 🛠️ Tech Stack
- **Frontend App:** Flutter (Dart), Provider (State Management), Fl_Chart, Google Fonts.
- **AI/Backend Model:** Python, OpenCV, Ultralytics YOLOv11.
- **Database:** Firebase Cloud Firestore (Real-time syncing).

---

## 🚀 Getting Started

### 1. Prerequisites
- **Flutter SDK:** Ensure you have Flutter `^3.3.0` installed.
- **Python:** Python `3.8+` for running the AI models.
- **Firebase:** A Firebase project configured for both Flutter and the Python Admin SDK.

### 2. Setup the Flutter App
```bash
cd frontend/smart_shuttle_app
flutter pub get
flutter run
```
> Note: The app currently uses a mock initial router on the Login Screen (`lib/screens/auth/login_screen.dart`). Use `admin@shuttle.lk`, `driver@shuttle.lk`, or any other email to route to the respective dashboards.

### 3. Setup the AI Passenger Counter
1. Place your `serviceAccountKey.json` from Firebase Admin into `backend/database/`.
2. Activate your Python virtual environment.
3. Install the dependencies: `pip install ultralytics opencv-python firebase-admin`.
4. Run the model:
   ```bash
   python ai_models/passenger_counting/test_yolo.py
   ```
> This will open your webcam to simulate the bus camera, run YOLOv11 to count people, and push live counts/revenue to the `live_status/bus_01` document in Firestore.

---

## 🤝 Contribution
Members: IT24200314 (Individual Contribution for AI-Powered Revenue Forecasting / Dashboard).

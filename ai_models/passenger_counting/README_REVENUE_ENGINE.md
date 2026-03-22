# 🚌 Smart Shuttle — AI Backend Engine

This folder contains the backend logic that connects your future **YOLOv11** object detection script to the Firebase cloud database to automate the daily revenue calculations.

## Files Created
1. **`db_seeder.py`**: Run this ONCE to fill your Firebase database with fake data (ticket prices, mock passenger logs, and revenue projections).
2. **`revenue_engine.py`**: The main bridge. It takes the "passenger count" from your AI, multiplies it by the ticket price (75 LKR), and updates the daily database totals automatically.

---

## ⚠️ CRITICAL: Firebase Authentication
You mentioned there is a JSON file in your `android/app` folder. That is `google-services.json`, which is only for the Flutter App. **Python requires a different file called a Service Account Key.**

To get it:
1. Go to your [Firebase Console](https://console.firebase.google.com/).
2. Click the **Gear Icon** (Project Settings) -> **Service Accounts** tab.
3. Click the **Generate New Private Key** button.
4. Download the file, rename it to `serviceAccountKey.json`, and place it in this exact folder (`ai_models/passenger_counting/`).

---

## 🛠️ How to integrate with your YOLOv11 Script

When you finish writing your `yolo.py` or AI script later, you don't need to write any database code. Just import the Engine!

```python
# 1. Import the engine
from revenue_engine import RevenueEngine

# 2. Initialize it BEFORE the video loop starts
engine = RevenueEngine(key_path="serviceAccountKey.json")

# ... inside your YOLO frame loop ...
while True:
    frames = camera.read()
    results = model(frames)
    
    new_passengers_detected = count_people_crossing_line(results)
    
    if new_passengers_detected > 0:
        # 3. Just call this one line! It handles all the math and database uploads
        engine.process_new_passengers(bus_id="bus_001", headcount_increase=new_passengers_detected)
```

## Setup Instructions
Before running anything, make sure you install the required Python Firebase admin SDK:
```bash
pip install firebase-admin
```

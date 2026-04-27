# Smart Shuttle AI Transport System

## Complete Final Evaluation and Viva Guide

## 1. Overall Project Intro

**Smart Shuttle AI Transport System** is an AI-based transport management system designed for university shuttle operations.

The system uses AI models, dashboards, backend APIs, and Firebase Firestore to make shuttle transport safer, smarter, and easier to manage.

The system has three main user roles:

- **Student**: View bus live location, check lost items, claim lost items, and submit feedback.
- **Driver**: Start trips, stop sessions, finalize trips, monitor passenger count, and support driver safety monitoring.
- **Admin**: Manage users, monitor revenue, view AI results, handle feedback, and manage Lost & Found claims.

The project combines:

- AI vision models for passenger counting, driver behavior detection, and lost item detection.
- FastAPI backend to connect AI models, frontend screens, and Firestore.
- Firebase Firestore to store live bus data, users, trips, revenue, feedback, and lost items.
- Flutter and React dashboards for real user interaction.

Simple Sinhala hint:

> Ape system eka shuttle bus operation eka smart karanne AI, dashboard, backend API, and database eka connect karala.

## 2. AI Components

## Passenger Counting AI

Responsible members:

- UPAMADA
- SHAMAL

### What It Does

Passenger Counting AI detects and counts passengers inside the shuttle using a YOLO-based object detection model.

It helps compare:

- AI-counted passengers
- Sold ticket count
- Unpaid passengers
- Revenue leakage

Example:

```text
AI counted passengers = 25
Tickets sold = 20
Unpaid passengers = 5
Revenue leakage = calculated automatically
```

### How It Works

- Input is a bus camera feed or demo video.
- YOLO-based model detects passengers frame by frame.
- Backend starts the AI model using Python subprocess.
- Passenger count is updated in Firestore.
- Final count is used for revenue calculation.

### Where It Is Used

- Driver Dashboard
- Admin Revenue Dashboard
- Backend trip finalization logic
- Firestore trip records

### Demo Explanation

In the demo:

1. Driver clicks **Start Session**.
2. Backend starts passenger counting AI.
3. Demo video or camera stream is processed.
4. Passenger count updates during the session.
5. Driver clicks **Stop Session** and then finalizes trip.
6. Final passenger count is saved.

Viva line:

> Our passenger counting model helps identify revenue leakage by comparing detected passenger count with sold ticket count.

## Driver Behavior Detection AI

Responsible members:

- AMANUKA
- KAVESH

### What It Does

Driver Behavior AI detects unsafe driver behavior such as:

- Phone usage
- Yawning
- Drowsiness-related behavior

### How It Works

- Camera frames are processed using trained YOLO-based models.
- Phone usage and yawn detection models identify risky behavior.
- Detected events are logged.
- Driver safety score and behavior counters are updated.
- Results are shown in the driver dashboard.

### Where It Is Used

- Driver Dashboard
- Driver safety score section
- Firestore driver behavior logs
- Admin safety monitoring

### Demo Explanation

In the demo:

1. Driver starts a session.
2. Driver behavior AI activates.
3. If phone usage or yawn is detected, the event count increases.
4. Driver safety status updates.
5. Logs are saved in Firestore.

Viva line:

> This model improves driver safety by monitoring risky behavior during active trips.

Sinhala hint:

> Driver phone eka use karanawada, yawn karanawada kiyala AI detect karanawa.

## Lost & Found AI

Responsible members:

- MITHEJ
- RISHAN

### What It Does

Lost & Found AI detects items left inside the shuttle after the trip or session ends.

Detected objects include:

- Bag
- Backpack
- Bottle
- Laptop
- Laptop bag
- Umbrella
- Book
- Other supported object classes

### How It Works

- Driver clicks **Stop Session** or finalizes trip.
- Backend launches Lost & Found AI using subprocess.
- AI opens the demo video:

```text
ai_models/lost_and_found/demo/demo.mp4
```

- YOLO model detects lost objects.
- Similar object classes are grouped to avoid duplicate saving.
- Detected items are saved to Firestore collection:

```text
lost_found_items
```

### Where It Is Used

- Admin Lost & Found UI
- Student Lost & Found UI
- Claim request workflow
- Firestore Lost & Found records

### Demo Explanation

In the demo:

1. Driver clicks **Stop Session**.
2. Lost & Found AI preview opens.
3. Demo video runs for around 60 seconds or full video if manually selected.
4. Model detects objects and draws boxes.
5. Detected items are saved as available items.
6. Student can request a claim.
7. Admin can approve, reject, cancel, or mark collected.

Viva line:

> Lost & Found AI is triggered after the session ends because that is the correct time to check whether passengers left items inside the shuttle.

## 3. Backend Explanation

## Backend Technology

The backend is built using:

- Python
- FastAPI
- REST APIs
- Firebase Admin SDK
- Python subprocess for AI execution

FastAPI acts as the central controller of the whole system.

Simple explanation:

> Frontend does not directly run AI models. Frontend sends requests. FastAPI starts AI processes, handles business logic, and updates Firestore.

## Backend Responsibilities

- User authentication
- User management
- Trip start and end logic
- Passenger counting AI launch
- Driver behavior AI launch
- Lost & Found AI launch
- Revenue calculation
- Feedback APIs
- Lost item claim workflow
- Firestore read/write operations

## Key Backend Files

```text
backend/
  main.py
  routes/
    auth_routes.py
    driver_routes.py
    dashboard_routes.py
    lost_found_routes.py
    map_routes.py
    feedback_routes.py
    user_routes.py
  services/
    passenger_counting_service.py
    driver_behavior_service.py
    ai_lost_found_service.py
    revenue_service.py
    feedback_service.py
    user_service.py
  utils/
    firebase_config.py
```

## Important Backend Endpoints

### Health / Root

```text
GET /
GET /health
```

Used to check whether the backend is running.

### Driver Trip Flow

```text
POST /driver/start-trip
POST /driver/stop-session
POST /driver/end-trip
```

Used by the Driver Dashboard.

### Revenue Dashboard

```text
GET /dashboard/revenue-summary
```

Used by Admin Dashboard to show:

- Total revenue
- Profit or loss
- Ticket leakage
- Trip performance

### Live Map

```text
GET /map/live-location/{bus_id}
POST /gps/update-location
```

Used by Student Map to show shuttle live location.

### Lost & Found

```text
GET /lost-found/items
GET /lost-found/items/available
POST /lost-found/items/{item_id}/claim
GET /lost-found/claims
POST /lost-found/claims/{claim_id}/approve
POST /lost-found/claims/{claim_id}/reject
POST /lost-found/claims/{claim_id}/cancel
POST /lost-found/items/{item_id}/mark-collected
```

Used by Admin and Student Lost & Found screens.

### Feedback

```text
POST /feedback
GET /feedback
```

Used by Student Feedback and Admin review features.

## How Frontend Connects

```text
Flutter / React UI
      ↓
FastAPI REST API
      ↓
Firebase Firestore
      ↓
AI results and dashboard data
```

Viva line:

> We followed clean architecture. UI handles presentation only. FastAPI handles AI execution, validation, business logic, and database updates.

## 4. Frontend Explanation

## Student App

### Main Features

- Student login
- View live shuttle location
- View available lost items
- Request lost item claim
- View claim status
- Submit feedback

### Student Flow

```text
Student logs in
→ Opens dashboard
→ Views live bus location
→ Checks Lost & Found
→ Sends claim request
→ Submits feedback
```

Viva line:

> Student app focuses on passenger experience: live tracking, feedback, and lost item claiming.

## Driver Dashboard

### Main Features

- Start trip
- Stop session
- End trip
- Show passenger count
- Show driver behavior safety status
- Send GPS updates
- Trigger Lost & Found AI demo at session end

### Driver Flow

```text
Driver starts trip
→ Passenger counting AI starts
→ Driver behavior AI starts
→ Live data updates
→ Driver stops session
→ Lost & Found AI starts
→ Driver finalizes trip
```

Viva line:

> Driver Dashboard is the operational control panel. It starts and stops AI-powered trip monitoring.

## Admin Dashboard

### Main Features

- Admin login/register
- User management
- Revenue dashboard
- Passenger and revenue leakage view
- Lost item management
- Claim approval/rejection/cancellation
- Feedback review

Viva line:

> Admin Dashboard gives management-level visibility into revenue, safety, users, feedback, and Lost & Found operations.

## 5. Member-Wise Explanation

## Member 1: UPAMADA

### Responsibilities

- Admin Dashboard Revenue UI
- Passenger Counting AI Model
- Model Training
- Model Integration

### Files / Folders

```text
ai_models/passenger_counting/
  demo_inference.py
  train_baseline.py
  runs/
  models/

backend/services/
  passenger_counting_service.py
  revenue_service.py

backend/routes/
  dashboard_routes.py

frontend/admin/
  revenue_dashboard/
```

### Viva Script

> My part was mainly the passenger counting AI and admin revenue dashboard. The AI model detects passengers from bus video frames. The final passenger count is sent to the backend and stored in Firestore. The revenue dashboard compares AI passenger count with sold ticket count to identify revenue leakage.

### Possible Questions and Answers

**Q: Why is passenger counting important?**

Passenger counting is important because ticket sales alone cannot show the actual number of passengers. AI passenger counting helps detect unpaid passengers and calculate revenue leakage.

**Q: Why YOLO?**

YOLO is fast and suitable for real-time object detection. Since passenger counting needs quick frame-by-frame detection, YOLO is a practical choice.

**Q: How does revenue leakage work?**

The backend compares AI passenger count with sold ticket count. If AI count is higher, the difference is treated as unpaid passengers.

## Member 2: SHAMAL

### Responsibilities

- Passenger counting preprocessing
- Image cleaning
- Labeling
- Student Dashboard
- Student Map API integration

### Files / Folders

```text
preprocessing/
  clean_frames.py
  extract_frames.py
  label_reviewer.py
  prepare_fewshot.py

frontend/student/
  student_dashboard/
  student_map_screen.dart

backend/routes/
  map_routes.py
```

### Viva Script

> My role was to prepare the dataset for passenger counting and build the student-side features. I cleaned images, helped with labeling, and connected the student map with backend live-location APIs. The student can see shuttle location and use student services from the dashboard.

### Possible Questions and Answers

**Q: Why is preprocessing needed?**

Raw images may contain blur, bad lighting, duplicate frames, or irrelevant data. Preprocessing improves dataset quality and model accuracy.

**Q: How does the live map work?**

Driver app sends GPS location to backend. Backend stores it in Firestore. Student app fetches live location through FastAPI map endpoints.

**Q: Why not read Firestore directly from the app?**

Backend gives better control, security, validation, and consistent API structure.

## Member 3: AMANUKA

### Responsibilities

- Driver Dashboard
- Driver Behavior Detection
- Phone usage model
- Model Training

### Files / Folders

```text
frontend/driver/
  driver_dashboard_screen.dart

ai_models/driver_behavior/
  phone/
    best.pt
    last.pt

backend/services/
  driver_behavior_service.py

backend/routes/
  driver_routes.py
```

### Viva Script

> My part was the Driver Dashboard and phone usage detection model. When the driver starts a trip, the driver behavior AI also starts. If phone usage is detected, the system records the event and updates the driver safety status.

### Possible Questions and Answers

**Q: How does phone usage detection help?**

It improves driver safety by identifying distracted driving behavior.

**Q: Is it real-time?**

Yes. The model processes camera frames during the active driver session and updates the backend.

**Q: What happens if the model fails?**

The backend handles errors safely. The trip flow continues, and warning logs are shown.

## Member 4: KAVESH

### Responsibilities

- Admin Authentication
- Login/Register
- User Management
- Edit/Delete users
- Yawn Detection Model

### Files / Folders

```text
backend/routes/
  auth_routes.py
  user_routes.py
  admin_routes.py

backend/services/
  user_service.py
  driver_behavior_service.py

ai_models/driver_behavior/
  yawn/
    best.pt
    last.pt

frontend/admin/
  auth/
  user_management/
```

### Viva Script

> My responsibility was authentication, user management, and yawn detection. Admin can register/login and manage users. I also worked on the yawn detection model, which supports driver behavior monitoring and safety scoring.

### Possible Questions and Answers

**Q: Why is user management important?**

The system has different roles: student, driver, and admin. User management controls access and keeps the system secure.

**Q: How are roles handled?**

User records contain role values such as student, driver, and admin. The frontend loads the correct dashboard based on the role.

**Q: Why detect yawning?**

Yawning can indicate fatigue. Detecting it helps identify driver tiredness during trips.

## Member 5: MITHEJ

### Responsibilities

- Feedback System
- Lost & Found YOLOv8 Model Training

### Files / Folders

```text
backend/routes/
  feedback_routes.py

backend/services/
  feedback_service.py

ai_models/lost_and_found/
  best.pt
  demo_inference.py
  demo/

frontend/student/
  feedback_screen/

frontend/admin/
  feedback_review/
```

### Viva Script

> My part was the feedback system and Lost & Found AI model training. Students can submit feedback after using the shuttle. For Lost & Found, I trained a YOLOv8-based model to detect objects left inside the bus.

### Possible Questions and Answers

**Q: Why have a feedback system?**

Feedback helps admins understand passenger satisfaction and improve shuttle service quality.

**Q: What data does feedback store?**

It stores student ID, trip ID, rating, comment, created time, and updated time.

**Q: What does the Lost & Found model detect?**

It detects objects like bags, bottles, laptops, books, umbrellas, and similar lost items.

## Member 6: RISHAN

### Responsibilities

- Lost & Found Admin UI
- Lost & Found Student UI
- YOLOv11 Model Integration
- Claim workflow

### Files / Folders

```text
frontend/student/
  student_lost_found_screen.dart

frontend/admin/
  admin_lost_found_screen.dart

backend/routes/
  lost_found_routes.py

backend/services/
  ai_lost_found_service.py

ai_models/lost_and_found/
  demo_inference.py
```

### Viva Script

> My responsibility was the Lost & Found system. When the driver stops the session, the backend starts the Lost & Found AI demo. Detected items are saved in Firestore. Students can view available items and request claims. Admin can approve, reject, cancel, or mark an item as collected.

### Possible Questions and Answers

**Q: Why trigger Lost & Found after session end?**

Lost items should be checked after passengers leave the shuttle. Running it at trip start is not logical because passengers may still be carrying their belongings.

**Q: How do you avoid duplicate items?**

The AI script groups detections by object class before saving. For example, multiple bag detections are saved as one bag item for the demo.

**Q: What happens after a student claims an item?**

A claim request is created. Admin reviews it and can approve, reject, cancel, or mark the item as collected.

## 6. Realistic Project File Structure

```text
smart-shuttle-ai-system/
│
├── backend/
│   ├── main.py
│   ├── requirements.txt
│   │
│   ├── routes/
│   │   ├── auth_routes.py
│   │   ├── driver_routes.py
│   │   ├── dashboard_routes.py
│   │   ├── map_routes.py
│   │   ├── lost_found_routes.py
│   │   ├── feedback_routes.py
│   │   └── user_routes.py
│   │
│   ├── services/
│   │   ├── passenger_counting_service.py
│   │   ├── driver_behavior_service.py
│   │   ├── ai_lost_found_service.py
│   │   ├── revenue_service.py
│   │   ├── feedback_service.py
│   │   └── user_service.py
│   │
│   ├── models/
│   │   └── schemas.py
│   │
│   └── utils/
│       ├── firebase_config.py
│       └── dependencies.py
│
├── ai_models/
│   ├── passenger_counting/
│   │   ├── demo_inference.py
│   │   ├── train_baseline.py
│   │   ├── models/
│   │   └── runs/
│   │
│   ├── driver_behavior/
│   │   ├── phone/
│   │   │   └── best.pt
│   │   └── yawn/
│   │       └── best.pt
│   │
│   └── lost_and_found/
│       ├── best.pt
│       ├── demo_inference.py
│       └── demo/
│           └── demo.mp4
│
├── preprocessing/
│   ├── extract_frames.py
│   ├── clean_frames.py
│   ├── label_reviewer.py
│   └── prepare_fewshot.py
│
├── frontend/
│   ├── smart_shuttle_app/
│   │   └── lib/
│   │       ├── screens/
│   │       │   ├── student/
│   │       │   ├── driver/
│   │       │   └── admin/
│   │       ├── providers/
│   │       ├── widgets/
│   │       └── utils/
│   │
│   └── admin_dashboard/
│       ├── src/
│       └── components/
│
└── docs/
    ├── API_REFERENCE.md
    ├── DATABASE_SCHEMA.md
    └── FINAL_EVALUATION_GUIDE.md
```

## 7. Demo Flow Step-by-Step

## Step 1: Admin Login

- Admin logs in.
- Admin dashboard loads.
- Admin can view users, revenue, Lost & Found, and feedback.

Say:

> First, admin logs in to monitor the complete transport system.

## Step 2: Driver Starts Trip

- Driver opens Driver Dashboard.
- Driver clicks **Start Session**.
- Backend creates a trip record.
- Passenger Counting AI starts.
- Driver Behavior AI starts.

Firestore updates:

```text
LIVE-STATUS
trips
driver_behavior_logs
```

Say:

> When the driver starts a trip, our backend starts both passenger counting and driver monitoring.

## Step 3: Passenger Counting Runs

- AI processes video or camera frames.
- Passenger count updates.
- Driver dashboard shows live passenger count.

Say:

> The passenger count is not manually entered. It comes from the AI model.

## Step 4: Live Map Updates

- Driver device sends GPS data.
- Backend saves live location.
- Student app fetches bus location.

Say:

> Students can see shuttle location using the map API.

## Step 5: Driver Behavior Detection

- Phone/yawn model runs.
- If behavior is detected, event count updates.
- Safety score changes.

Say:

> This part focuses on driver safety.

## Step 6: Driver Stops Session

- Driver clicks **Stop Session**.
- Passenger AI stops.
- Lost & Found AI starts.
- Demo video opens.
- Lost objects are detected.

Say:

> At session end, Lost & Found AI checks whether passengers left objects inside the shuttle.

## Step 7: Driver Finalizes Trip

- Driver enters ticket counts.
- Backend calculates revenue.
- Revenue leakage is calculated.
- Trip status becomes completed.

Say:

> The final passenger count is compared with ticket count to calculate leakage.

## Step 8: Admin Revenue Dashboard Updates

Admin sees:

- Total revenue
- Profit or loss
- Ticket leakage
- AI passenger count
- Sold ticket count

Say:

> Admin gets decision-support information, not just raw data.

## Step 9: Student Claims Lost Item

- Student opens Lost & Found.
- Student views available item.
- Student clicks claim request.

Say:

> Students can claim items without directly changing item status.

## Step 10: Admin Handles Claim

Admin can:

- Approve
- Reject
- Cancel
- Mark collected

Say:

> Admin controls the final Lost & Found handover process.

## 8. Common Viva Questions and Best Answers

## Q1: Why did you use YOLO?

YOLO is fast, accurate, and suitable for real-time object detection. Our project needs frame-by-frame detection for passengers, driver behavior, and lost items, so YOLO is a practical choice.

## Q2: Why FastAPI?

FastAPI is lightweight, fast, and easy to integrate with Python AI models. Since our AI models are written in Python, FastAPI is suitable for connecting AI, frontend, and Firestore.

## Q3: Why Firebase Firestore?

Firestore supports cloud-based data storage and is easy to integrate with web/mobile apps. It is useful for live bus status, user data, trip data, feedback, and Lost & Found records.

## Q4: How does real-time update work?

The driver dashboard sends updates to backend. Backend updates Firestore. Student and admin dashboards fetch updated data through APIs. For demo, polling and API refresh are used.

## Q5: Why not run AI directly in Flutter or React?

AI models need Python libraries like OpenCV and YOLO. Running them in backend is cleaner, more secure, and easier to manage. Frontend should only handle UI.

## Q6: How do you calculate revenue leakage?

Revenue leakage is calculated by comparing AI passenger count with sold tickets.

```text
Unpaid passengers = AI passenger count - sold tickets
Leakage amount = unpaid passengers × average ticket value
```

## Q7: What happens if the AI model fails?

The system has error handling. The backend logs warnings, the trip flow continues, and the app does not crash. This is important for real-world reliability.

## Q8: Why does Lost & Found run after Stop Session or End Trip?

Lost items can only be confirmed after passengers leave. Running it during the trip may detect passengers' current belongings incorrectly.

## Q9: How do you avoid duplicate lost items?

For demo, detections are grouped by object type. If the model detects many bags, it saves one grouped bag record instead of many duplicate records.

## Q10: What are the limitations?

- Accuracy depends on camera angle and lighting.
- Demo uses prerecorded video.
- Real deployment needs physical bus cameras.
- Model may confuse similar objects.
- Internet connection is needed for Firebase.

## Q11: What are future improvements?

- Deploy on actual bus cameras.
- Add object tracking.
- Add push notifications.
- Improve dataset size.
- Add automatic lost item image upload.
- Add route prediction.
- Improve real-time streaming.

## 9. Key Points to Focus During Presentation

## What Impresses Evaluators

Focus on:

- Clear system architecture
- AI plus software integration
- Real transport use case
- Role-based dashboards
- Firestore data flow
- Revenue leakage logic
- Driver safety monitoring
- Lost & Found claim workflow

Strong line:

> This is not only an AI model project. It is a complete AI-integrated transport management system.

## What To Avoid

Avoid saying:

- We just used YOLO.
- Frontend directly connects everything.
- This is only a demo.
- We trained model and displayed output.

Better say:

> We integrated trained AI models into a working transport workflow using FastAPI, Firestore, and role-based dashboards.

## How To Answer Confidently

Use this pattern:

```text
Problem → Our solution → Technology → Result
```

Example:

> The problem is revenue leakage. Our solution is AI passenger counting. We used YOLO to detect passengers and FastAPI to save counts. As a result, admin can compare passenger count with ticket sales.

## Final Short Presentation Script

> Our project is Smart Shuttle AI Transport System. It is designed to improve university shuttle operations using AI and dashboards. The system has three main users: student, driver, and admin. Driver starts a trip, passenger counting AI and driver behavior AI run, live data is stored in Firebase, and admin can monitor revenue and safety. When the session ends, Lost & Found AI checks the bus video and saves detected items. Students can claim items, and admins approve or reject those claims. Our backend is FastAPI, database is Firebase Firestore, frontend is Flutter and React, and AI models are YOLO-based.

Sinhala confidence hint:

> Saralawa kiwwoth, bus operation eka AI walin smart karala admin, driver, student thundenatama useful system ekak hadala thiyenne.


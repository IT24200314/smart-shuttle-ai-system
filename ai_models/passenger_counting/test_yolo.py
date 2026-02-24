import cv2
import firebase_admin
from firebase_admin import credentials, firestore
from ultralytics import YOLO

print("1. Connecting to Firebase...")
# ඔයාගේ JSON ෆයිල් එකේ Path එක මෙතන හරියටම තියෙනවාද බලන්න
cred = credentials.Certificate("backend/database/serviceAccountKey.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("2. Loading AI Model...")
model = YOLO("yolo11n.pt") # හෝ ඔයාගේ path එක දෙන්න

ticket_price = 50.0
cap = cv2.VideoCapture(0)

while cap.isOpened():
    success, frame = cap.read()
    if not success:
        break

    # AI Inference
    results = model(frame, classes=[0], conf=0.5)
    passenger_count = len(results[0].boxes)
    estimated_revenue = passenger_count * ticket_price

    # තිරයේ පෙන්වීම
    annotated_frame = results[0].plot()
    cv2.putText(annotated_frame, f"Count: {passenger_count} | Rev: {estimated_revenue}", (20, 50), 
                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
    cv2.imshow("Smart Shuttle AI", annotated_frame)

    # ---------------------------------------------------------
    # ප්රශ්නය හොයාගන්නා Debug කොටස
    print(f"AI Detected: {passenger_count} | Sending to Firebase...")
    
    try:
        doc_ref = db.collection('live_status').document('bus_01')
        doc_ref.set({
            'passenger_count': passenger_count,
            'estimated_revenue': estimated_revenue
        })
        print("✅ Firebase Update Success!")
    except Exception as e:
        print(f"❌ FIREBASE ERROR: {e}")
    # ---------------------------------------------------------

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()
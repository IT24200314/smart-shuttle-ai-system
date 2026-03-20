import cv2
from ultralytics import YOLO
import firebase_admin
from firebase_admin import credentials, firestore

# --- 1. Firebase Setup ---
# Provide the correct path to your serviceAccountKey.json file here
CREDENTIALS_PATH = r"C:\suttle project\smart-shuttle-ai-system\backend\database\serviceAccountKey.json"

try:
    cred = credentials.Certificate(CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase Connected Successfully!")
except Exception as e:
    print(f"❌ Firebase Connection Error: {e}")
    print("Please check if the serviceAccountKey.json file is in the correct location.")
    exit()

# --- 2. System Constants ---
TICKET_PRICE = 100.0  # Price of one ticket
BUS_ID = "bus_001"    # The ID of this bus

def main():
    # 3. Load the AI model
    model_path = r"C:\suttle project\smart-shuttle-ai-system\ai_models\passenger_counting\runs\detect\bus_passenger_model6\weights\best.pt"
    model = YOLO(model_path)

    print("🎥 Starting Passenger Counting & Revenue Engine... (Press 'q' to stop)")
    # Using cv2.CAP_DSHOW provides faster and more reliable camera access on Windows
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)

    if not cap.isOpened():
        print("❌ Error: Could not open the webcam. Please make sure it's not being used by another app.")
        return

    last_count = -1  # Variable used to check if the passenger count has changed

    # 4. AI Inference Loop
    print("⏳ Waiting for the first frame (the AI might take a few seconds to warm up)...")
    while cap.isOpened():
        success, frame = cap.read()
        if not success:
            print("❌ Cannot get images from the camera! It might be disconnected or used by another app.")
            break

        results = model.predict(source=frame, conf=0.25, verbose=False)
        r = results[0]
        
        boxes = r.boxes
        current_count = len(boxes)
        current_revenue = current_count * TICKET_PRICE

        # 5. Firebase Update Logic (send only if changed)
        if current_count != last_count:
            try:
                # Updating the document of the respective bus in the LIVE-STATUS collection
                db.collection("LIVE-STATUS").document(BUS_ID).set({
                    "bus_id": BUS_ID,
                    "passenger_count": current_count,
                    "estimated_revenue": current_revenue
                }, merge=True) # merge=True is very important! It prevents overwriting other data
                
                print(f"☁️ Firebase Updated -> Passengers: {current_count} | Revenue: Rs. {current_revenue}")
                last_count = current_count # Save the new count
            except Exception as e:
                print(f"⚠️ Failed to update Firebase: {e}")

        # 6. Display on screen
        annotated_frame = r.plot()
        
        # Displaying details on the UI
        cv2.putText(annotated_frame, f"Passengers: {current_count}", (20, 50), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
        cv2.putText(annotated_frame, f"Revenue: Rs. {current_revenue}", (20, 90), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2)

        cv2.imshow("Smart Shuttle - AI Vision & Revenue", annotated_frame)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
            
    cap.release()
    cv2.destroyAllWindows()

if __name__ == '__main__':
    main()

import sys
import os
import time
import cv2
from datetime import datetime
from ultralytics import YOLO

# Add parent directory to path to allow importing from utils
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.firebase_config import db

def main(email):
    # Initialize connection to db
    if not db:
        print("Failed to connect to Firebase. Exiting camera script.")
        return

    date_str = datetime.now().strftime('%Y-%m-%d')
    doc_id = f"{email}_{date_str}"
    doc_ref = db.collection('driver_behavior_logs').document(doc_id)
    
    # Load YOLO Model
    model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../ai_models/driver_behavior/best.pt'))
    try:
        model = YOLO(model_path)
    except Exception as e:
        print(f"Failed to load YOLO model: {e}")
        return

    # Session state to toggle camera on/off
    session_state = {"active": False, "running": True}
    
    def on_snapshot(doc_snapshot, changes, read_time):
        for doc in doc_snapshot:
            if doc.exists:
                session_state["active"] = doc.to_dict().get("session_active", False)

    doc_watch = doc_ref.on_snapshot(on_snapshot)

    cap = None

    # Cooldown setup to prevent database spamming
    last_event_time = {
        'yawn': 0.0,
        'usephone': 0.0,
        'drowsiness': 0.0
    }
    cooldown_seconds = 5

    print(f"Starting driver behavior monitor for {email}...")

    while session_state["running"]:
        if session_state["active"]:
            if cap is None or not cap.isOpened():
                print("Session started, opening camera...")
                cap = cv2.VideoCapture(0)
            
            if cap is None or not cap.isOpened():
                time.sleep(1)
                continue

            ret, frame = cap.read()
            if not ret:
                continue

            # Run inference
            results = model(frame, verbose=False)
            
            detected_text = ""
            event_trigger = ""

            for r in results:
                boxes = r.boxes
                for box in boxes:
                    cls_id = int(box.cls[0])
                    conf = float(box.conf[0])
                    
                    # Check confidence threshold
                    if conf < 0.5:
                        continue

                    class_name = r.names[cls_id].lower().replace(" ", "")

                    if "yawn" in class_name:
                        event_trigger = "yawn"
                        detected_text = "Yawn detected"
                    elif "usephone" in class_name or "phone" in class_name:
                        event_trigger = "usephone"
                        detected_text = "Use phone detected"
                    elif "drows" in class_name:
                        event_trigger = "drowsiness"
                        detected_text = "Drowsiness detected"

            # Handle UI Text and Database Updates
            if event_trigger != "":
                # Draw visual alert
                cv2.putText(frame, detected_text, (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 
                            1, (0, 0, 255), 2, cv2.LINE_AA)

                current_time = float(time.time())
                if current_time - last_event_time[event_trigger] > cooldown_seconds:
                    try:
                        # Perform database update via transaction or simple getting and updating
                        # Here we fetch the current doc, because we modify multiple things
                        doc = doc_ref.get()
                        if doc.exists:
                            data = doc.to_dict()
                            score = data.get('safety_score', 100)
                            
                            updates = {}
                            if event_trigger == "yawn":
                                updates['number_of_ywan'] = data.get('number_of_ywan', 0) + 1
                                updates['safety_score'] = score - 1
                            elif event_trigger == "usephone":
                                updates['number_of_usephone'] = data.get('number_of_usephone', 0) + 1
                                updates['safety_score'] = score - 2
                            elif event_trigger == "drowsiness":
                                updates['number_of_drowsiness'] = data.get('number_of_drowsiness', 0) + 1
                                updates['safety_score'] = score - 5
                                
                            doc_ref.update(updates)
                            print(f"Logged {detected_text} into DB. Updated score: {updates['safety_score']}")

                    except Exception as e:
                        print(f"Error updating Firestore: {e}")

                    last_event_time[event_trigger] = current_time

            cv2.imshow('Driver Behavior Monitor', frame)

            # Press 'q' to quit
            if cv2.waitKey(1) & 0xFF == ord('q'):
                session_state["running"] = False
                break
        else:
            if cap is not None and cap.isOpened():
                print("Session stopped, closing camera...")
                cap.release()
                cv2.destroyAllWindows()
                cap = None
            time.sleep(1)

    if cap is not None and cap.isOpened():
        cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        email_arg = sys.argv[1]
        main(email_arg)
    else:
        print("Please provide a driver email as an argument.")

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
    model_path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), '../ai_models/driver_behavior/best.pt')
    )

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

    try:
        doc_watch = doc_ref.on_snapshot(on_snapshot)
    except Exception as e:
        print(f"Error setting up Firestore listener: {e}")
        print("Exiting driver behavior monitor...")
        return

    cap = None

    # Cooldown to prevent repeated DB updates
    last_event_time = {
        'yawn': 0.0,
        'usephone': 0.0,
        'drowsiness': 0.0
    }
    cooldown_seconds = 5

    # Need continuous detection for 1 second before updating
    detection_start_time = {
        'yawn': None,
        'usephone': None,
        'drowsiness': None
    }
    detection_required_seconds = 1

    print(f"Starting driver behavior monitor for {email}...")

    while session_state["running"]:
        if session_state["active"]:
            if cap is None or not cap.isOpened():
                print("Session started, opening camera...")
                cap = cv2.VideoCapture(0)
                if cap and cap.isOpened():
                    # Update camera_active flag
                    try:
                        doc_ref.set({'camera_active': True, 'monitor_state': 'monitoring'}, merge=True)
                    except Exception as e:
                        print(f"Error updating camera_active status: {e}")

            if cap is None or not cap.isOpened():
                time.sleep(1)
                continue

            ret, frame = cap.read()
            if not ret:
                continue

            # Run inference
            results = model(frame, verbose=False)

            # Current frame detections
            found_events = {
                'yawn': False,
                'usephone': False,
                'drowsiness': False
            }

            for r in results:
                boxes = r.boxes
                for box in boxes:
                    cls_id = int(box.cls[0])
                    conf = float(box.conf[0])

                    # Confidence threshold
                    if conf < 0.5:
                        continue

                    class_name = r.names[cls_id].lower().replace(" ", "")

                    if "yawn" in class_name:
                        found_events['yawn'] = True
                    elif "usephone" in class_name or "phone" in class_name:
                        found_events['usephone'] = True
                    elif "drows" in class_name:
                        found_events['drowsiness'] = True

            current_time = time.time()
            detected_text = ""
            event_trigger = ""

            # Update detection timers
            for event_name in detection_start_time.keys():
                if found_events[event_name]:
                    if detection_start_time[event_name] is None:
                        detection_start_time[event_name] = current_time
                else:
                    detection_start_time[event_name] = None

            # Check whether any event has been continuously detected for 3 seconds
            # Priority can be changed if needed
            if (
                detection_start_time['usephone'] is not None and
                current_time - detection_start_time['usephone'] >= detection_required_seconds
            ):
                event_trigger = 'usephone'
                detected_text = "Use phone detected"

            elif (
                detection_start_time['drowsiness'] is not None and
                current_time - detection_start_time['drowsiness'] >= detection_required_seconds
            ):
                event_trigger = 'drowsiness'
                detected_text = "Drowsiness detected"

            elif (
                detection_start_time['yawn'] is not None and
                current_time - detection_start_time['yawn'] >= detection_required_seconds
            ):
                event_trigger = 'yawn'
                detected_text = "Yawn detected"

            # Handle UI Text and Database Updates
            if event_trigger != "":
                # Draw visual alert
                cv2.putText(
                    frame,
                    detected_text,
                    (50, 50),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    (0, 0, 255),
                    2,
                    cv2.LINE_AA
                )

                # Update DB only after cooldown
                if current_time - last_event_time[event_trigger] > cooldown_seconds:
                    try:
                        doc = doc_ref.get(timeout=5)
                        if doc.exists:
                            data = doc.to_dict()
                            score = data.get('safety_score', 100)

                            updates = {}
                            if event_trigger == "yawn":
                                updates['number_of_ywan'] = data.get('number_of_ywan', 0) + 1
                                updates['safety_score'] = score - 1
                                updates['latest_event_type'] = 'yawn'
                                updates['latest_event_label'] = detected_text
                                updates['latest_event_at'] = datetime.now().isoformat()
                            elif event_trigger == "usephone":
                                updates['number_of_usephone'] = data.get('number_of_usephone', 0) + 1
                                updates['safety_score'] = score - 2
                                updates['latest_event_type'] = 'usephone'
                                updates['latest_event_label'] = detected_text
                                updates['latest_event_at'] = datetime.now().isoformat()
                            elif event_trigger == "drowsiness":
                                updates['number_of_drowsiness'] = data.get('number_of_drowsiness', 0) + 1
                                updates['safety_score'] = score - 5
                                updates['latest_event_type'] = 'drowsiness'
                                updates['latest_event_label'] = detected_text
                                updates['latest_event_at'] = datetime.now().isoformat()

                            doc_ref.update(updates)
                            print(f"Logged {detected_text} into DB. Updated score: {updates.get('safety_score', score)}")

                            # Reset that event timer after successful update
                            detection_start_time[event_trigger] = None
                            last_event_time[event_trigger] = current_time

                    except Exception as e:
                        print(f"Error updating Firestore: {e}")

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
                # Update camera_active flag
                try:
                    doc_ref.set({'camera_active': False, 'monitor_state': 'idle'}, merge=True)
                except Exception as e:
                    print(f"Error updating camera_active status: {e}")
            time.sleep(1)

    if cap is not None and cap.isOpened():
        cap.release()

    cv2.destroyAllWindows()
    doc_watch.unsubscribe()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        email_arg = sys.argv[1]
        main(email_arg)
    else:
        print("Please provide a driver email as an argument.")

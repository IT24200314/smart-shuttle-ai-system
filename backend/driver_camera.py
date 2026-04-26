import argparse
import os
import sys
import time
import json
import cv2
from datetime import datetime
from ultralytics import YOLO

# Add parent directory to path to allow importing from utils
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.firebase_config import db


_UNSET = object()


def _normalize_class_name(names, cls_id: int) -> str:
    raw_name = ""
    if isinstance(names, dict):
        raw_name = names.get(cls_id, "")
    elif isinstance(names, (list, tuple)) and 0 <= cls_id < len(names):
        raw_name = names[cls_id]
    return str(raw_name).strip().lower().replace(" ", "").replace("_", "")


def _append_overlay_message(messages: list[str], message: str) -> None:
    if message not in messages:
        messages.append(message)


def _collect_detected_events(
    results,
    *,
    model_family: str,
    found_events: dict[str, bool],
    overlay_messages: list[str],
) -> None:
    for result in results:
        boxes = result.boxes
        if boxes is None:
            continue
        for box in boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])
            if conf < 0.5:
                continue

            class_name = _normalize_class_name(result.names, cls_id)
            if model_family == "yawn":
                if "drows" in class_name:
                    found_events["drowsiness"] = True
                    _append_overlay_message(overlay_messages, "DROWSINESS DETECTED")
                elif "yawn" in class_name:
                    found_events["yawn"] = True
                    _append_overlay_message(overlay_messages, "YAWN DETECTED")
            elif model_family == "phone":
                if "usephone" in class_name or "phone" in class_name:
                    found_events["usephone"] = True
                    _append_overlay_message(overlay_messages, "PHONE DETECTED")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--driver_email", required=True, type=str)
    parser.add_argument("--yawn_model_path", required=True, type=str)
    parser.add_argument("--phone_model_path", required=True, type=str)
    parser.add_argument("--stop_signal_path", required=True, type=str)
    parser.add_argument("--state_path", required=True, type=str)
    parser.add_argument("--driver_id", default="", type=str)
    parser.add_argument("--driver_name", default="", type=str)
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()

    email = args.driver_email.strip().lower()

    if not db:
        print("Failed to connect to Firebase. Exiting camera script.")
        return

    date_str = datetime.now().strftime('%Y-%m-%d')
    doc_id = f"{email}_{date_str}"
    doc_ref = db.collection('driver_behavior_logs').document(doc_id)

    def write_state(pid, *, monitor_state=None, camera_active=None, camera_error=_UNSET):
        try:
            payload = {
                "pid": pid,
                "monitor_state": (
                    monitor_state
                    if monitor_state is not None
                    else "monitoring" if session_state["active"] else "stopped"
                ),
                "camera_active": (
                    bool(camera_active)
                    if camera_active is not None
                    else session_state["active"]
                ),
                "model_path": args.yawn_model_path,
                "yawn_model_path": args.yawn_model_path,
                "phone_model_path": args.phone_model_path,
            }
            if camera_error is not _UNSET:
                payload["camera_error"] = camera_error
            with open(args.state_path, "w", encoding="utf-8") as f:
                json.dump(payload, f)
        except Exception:
            pass

    try:
        yawn_model = YOLO(args.yawn_model_path)
        phone_model = YOLO(args.phone_model_path)
    except Exception as e:
        error_message = f"Failed to load dual YOLO models: {e}"
        print(error_message)
        write_state(
            os.getpid(),
            monitor_state="failed",
            camera_active=False,
            camera_error=error_message,
        )
        try:
            doc_ref.set(
                {
                    "camera_active": False,
                    "monitor_state": "failed",
                    "camera_error": error_message,
                },
                merge=True,
            )
        except Exception:
            pass
        return

    session_state = {"active": False, "running": True}

    def on_snapshot(doc_snapshot, changes, read_time):
        for doc in doc_snapshot:
            if doc.exists:
                session_state["active"] = doc.to_dict().get("session_active", False)

    try:
        doc_watch = doc_ref.on_snapshot(on_snapshot)
    except Exception as e:
        print(f"Error setting up Firestore listener: {e}")
        return

    write_state(os.getpid())
    cap = None

    last_event_time = {'yawn': 0.0, 'usephone': 0.0, 'drowsiness': 0.0}
    cooldown_seconds = 5
    detection_start_time = {'yawn': None, 'usephone': None, 'drowsiness': None}
    detection_required_seconds = 1

    print(f"Starting driver behavior monitor for {email}...")

    def is_stop_requested():
        return os.path.exists(args.stop_signal_path)

    while session_state["running"] and not is_stop_requested():
        if session_state["active"]:
            if cap is None or not cap.isOpened():
                print("Session started, opening camera...")
                if cap is not None:
                    cap.release()
                    cap = None
                write_state(
                    os.getpid(),
                    monitor_state="camera_opening",
                    camera_active=False,
                    camera_error=None,
                )
                cap = cv2.VideoCapture(0)
                if cap and cap.isOpened():
                    try:
                        doc_ref.set(
                            {
                                'camera_active': True,
                                'monitor_state': 'monitoring',
                                'camera_error': None,
                            },
                            merge=True,
                        )
                    except Exception as e:
                        print(f"Error updating camera_active status: {e}")
                    write_state(
                        os.getpid(),
                        monitor_state="monitoring",
                        camera_active=True,
                        camera_error=None,
                    )

            if cap is None or not cap.isOpened():
                camera_error = "Unable to open laptop camera."
                write_state(
                    os.getpid(),
                    monitor_state="camera_unavailable",
                    camera_active=False,
                    camera_error=camera_error,
                )
                try:
                    doc_ref.set(
                        {
                            'camera_active': False,
                            'monitor_state': 'camera_unavailable',
                            'camera_error': camera_error,
                        },
                        merge=True,
                    )
                except Exception:
                    pass
                time.sleep(1)
                continue

            ret, frame = cap.read()
            if not ret:
                cap.release()
                cap = None
                time.sleep(0.2)
                continue

            try:
                yawn_results = yawn_model(frame, verbose=False)
                phone_results = phone_model(frame, verbose=False)
            except Exception as e:
                inference_error = f"Dual-model inference failed: {e}"
                print(inference_error)
                write_state(
                    os.getpid(),
                    monitor_state="failed",
                    camera_active=cap is not None and cap.isOpened(),
                    camera_error=inference_error,
                )
                try:
                    doc_ref.set(
                        {
                            'camera_active': cap is not None and cap.isOpened(),
                            'monitor_state': 'failed',
                            'camera_error': inference_error,
                        },
                        merge=True,
                    )
                except Exception:
                    pass
                time.sleep(1)
                continue

            found_events = {'yawn': False, 'usephone': False, 'drowsiness': False}
            overlay_messages = []
            _collect_detected_events(
                yawn_results,
                model_family="yawn",
                found_events=found_events,
                overlay_messages=overlay_messages,
            )
            _collect_detected_events(
                phone_results,
                model_family="phone",
                found_events=found_events,
                overlay_messages=overlay_messages,
            )

            current_time = time.time()
            detected_text = ""
            event_trigger = ""

            for event_name in detection_start_time.keys():
                if found_events[event_name]:
                    if detection_start_time[event_name] is None:
                        detection_start_time[event_name] = current_time
                else:
                    detection_start_time[event_name] = None

            if detection_start_time['usephone'] is not None and current_time - detection_start_time['usephone'] >= detection_required_seconds:
                event_trigger = 'usephone'
                detected_text = "PHONE DETECTED"
            elif detection_start_time['drowsiness'] is not None and current_time - detection_start_time['drowsiness'] >= detection_required_seconds:
                event_trigger = 'drowsiness'
                detected_text = "DROWSINESS DETECTED"
            elif detection_start_time['yawn'] is not None and current_time - detection_start_time['yawn'] >= detection_required_seconds:
                event_trigger = 'yawn'
                detected_text = "YAWN DETECTED"

            if not args.headless and overlay_messages:
                for index, message in enumerate(overlay_messages):
                    cv2.putText(
                        frame,
                        message,
                        (50, 50 + (index * 40)),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        1,
                        (0, 0, 255),
                        2,
                        cv2.LINE_AA,
                    )

            if event_trigger != "":
                if current_time - last_event_time[event_trigger] > cooldown_seconds:
                    try:
                        doc = doc_ref.get(timeout=5)
                        if doc.exists:
                            data = doc.to_dict()
                            score = data.get('safety_score', 100)

                            updates = {}
                            if event_trigger == "yawn":
                                updates['number_of_yawn'] = data.get('number_of_yawn', data.get('number_of_ywan', 0)) + 1
                                updates['safety_score'] = max(0, score - 1)
                            elif event_trigger == "usephone":
                                updates['number_of_usephone'] = data.get('number_of_usephone', 0) + 1
                                updates['safety_score'] = max(0, score - 2)
                            elif event_trigger == "drowsiness":
                                updates['number_of_drowsiness'] = data.get('number_of_drowsiness', 0) + 1
                                updates['safety_score'] = max(0, score - 5)

                            updates['latest_event_type'] = event_trigger
                            updates['latest_event_label'] = detected_text
                            updates['latest_event_at'] = datetime.now().isoformat()

                            doc_ref.set(updates, merge=True)
                            print(f"Logged {detected_text} into DB. Updated score: {updates['safety_score']}")

                            detection_start_time[event_trigger] = None
                            last_event_time[event_trigger] = current_time
                    except Exception as e:
                        print(f"Error updating Firestore: {e}")

            if not args.headless:
                cv2.imshow('Driver Behavior Monitor', frame)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    session_state["running"] = False
                    break
        else:
            if cap is not None and cap.isOpened():
                print("Session stopped, closing camera...")
                cap.release()
                if not args.headless:
                    cv2.destroyAllWindows()
                cap = None
                try:
                    doc_ref.set(
                        {
                            'camera_active': False,
                            'monitor_state': 'idle',
                            'camera_error': None,
                        },
                        merge=True,
                    )
                except Exception as e:
                    print(f"Error updating camera_active status: {e}")
                write_state(
                    os.getpid(),
                    monitor_state="idle",
                    camera_active=False,
                    camera_error=None,
                )
            time.sleep(1)

    if cap is not None and cap.isOpened():
        cap.release()

    if not args.headless:
        cv2.destroyAllWindows()
    doc_watch.unsubscribe()
    try:
        doc_ref.set(
            {
                'camera_active': False,
                'monitor_state': 'stopped',
                'camera_error': None,
            },
            merge=True,
        )
    except Exception as e:
        pass
    write_state(
        os.getpid(),
        monitor_state="stopped",
        camera_active=False,
        camera_error=None,
    )

if __name__ == "__main__":
    main()

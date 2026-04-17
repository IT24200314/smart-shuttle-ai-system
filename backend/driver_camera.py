from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime

import cv2
from ultralytics import YOLO


BACKEND_ROOT = os.path.dirname(os.path.abspath(__file__))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from utils.firebase_config import db


WINDOW_NAME = "Driver Behavior Monitor"
FIRESTORE_TIMEOUT_SECONDS = 3.0


def _now_iso() -> str:
    return datetime.now().isoformat()


def _normalize_driver_email(driver_email: str) -> str:
    return (driver_email or "").strip().lower()


def _today_doc_id(driver_email: str) -> str:
    date_str = datetime.now().strftime("%Y-%m-%d")
    return f"{_normalize_driver_email(driver_email)}_{date_str}"


def _write_state_file(path: str, payload: dict) -> None:
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle)
    except OSError as exc:
        print(f"[DRIVER-AI] Warning: failed to write state file '{path}': {exc}")


def _stop_requested(stop_signal_path: str) -> bool:
    return bool(stop_signal_path) and os.path.exists(stop_signal_path)


def _prepare_preview_window(preview_requested: bool) -> bool:
    if not preview_requested:
        print("[DRIVER-AI] Preview window disabled. Running in headless mode.")
        return False

    if sys.platform != "win32" and not os.environ.get("DISPLAY"):
        print("[DRIVER-AI] Preview fallback to headless mode (no display detected).")
        return False

    try:
        cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(WINDOW_NAME, 960, 540)
        print("[DRIVER-AI] Preview window opened.")
        return True
    except Exception as exc:
        print(f"[DRIVER-AI] Preview fallback to headless mode: {exc}")
        return False


def _close_preview_window(preview_open: bool) -> None:
    if not preview_open:
        return

    try:
        cv2.destroyWindow(WINDOW_NAME)
    except Exception:
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass
    print("[DRIVER-AI] Preview window closed.")


def _open_camera() -> cv2.VideoCapture | None:
    candidates: list[cv2.VideoCapture] = []
    if sys.platform == "win32":
        candidates.append(cv2.VideoCapture(0, cv2.CAP_DSHOW))
        candidates.append(cv2.VideoCapture(0))
    else:
        candidates.append(cv2.VideoCapture(0))

    for capture in candidates:
        if capture is not None and capture.isOpened():
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
            return capture
        if capture is not None:
            capture.release()
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--driver_email", required=True, type=str)
    parser.add_argument("--model_path", required=True, type=str)
    parser.add_argument("--stop_signal_path", required=True, type=str)
    parser.add_argument("--state_path", required=True, type=str)
    parser.add_argument("--driver_id", default="", type=str)
    parser.add_argument("--driver_name", default="", type=str)
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()

    driver_email = _normalize_driver_email(args.driver_email)
    if not driver_email:
        print("[DRIVER-AI] driver_email is required.")
        sys.exit(1)

    if db is None:
        print("[DRIVER-AI] Failed to connect to Firebase. Exiting driver behavior runtime.")
        sys.exit(1)

    doc_ref = db.collection("driver_behavior_logs").document(_today_doc_id(driver_email))
    preview_requested = not args.headless
    preview_mode = "preview" if preview_requested else "headless"
    preview_open = False
    last_runtime_signature: dict | None = None

    def publish_runtime_state(payload: dict) -> None:
        nonlocal last_runtime_signature
        if payload == last_runtime_signature:
            return

        last_runtime_signature = payload.copy()
        full_payload = {
            **payload,
            "updated_at": _now_iso(),
        }
        _write_state_file(args.state_path, full_payload)
        try:
            doc_ref.set(
                full_payload,
                merge=True,
                timeout=FIRESTORE_TIMEOUT_SECONDS,
            )
        except Exception as exc:
            print(
                "[DRIVER-AI] Warning: failed to update "
                f"driver_behavior_logs/{doc_ref.id}: {exc}"
            )

    base_payload = {
        "driver_id": args.driver_id or None,
        "driver_name": args.driver_name or None,
        "email": driver_email,
        "date": datetime.now().strftime("%Y-%m-%d"),
        "ai_model_path": args.model_path,
        "ai_preview_mode": preview_mode,
    }

    session_state = {"active": False}
    existing_data: dict = {}
    try:
        existing_doc = doc_ref.get(timeout=FIRESTORE_TIMEOUT_SECONDS)
        if existing_doc.exists:
            existing_data = existing_doc.to_dict() or {}
            session_state["active"] = bool(existing_data.get("session_active", False))
    except Exception:
        session_state["active"] = False

    initial_payload = {
        **base_payload,
        "number_of_yawn": int(
            existing_data.get("number_of_yawn", existing_data.get("number_of_ywan", 0))
            or 0
        ),
        "number_of_usephone": int(existing_data.get("number_of_usephone", 0) or 0),
        "number_of_drowsiness": int(
            existing_data.get("number_of_drowsiness", 0) or 0
        ),
        "safety_score": int(existing_data.get("safety_score", 100) or 100),
        "session_active": session_state["active"],
        "camera_active": False,
        "monitor_state": existing_data.get("monitor_state", "ready"),
        "camera_error": existing_data.get("camera_error"),
        "latest_event_type": existing_data.get("latest_event_type"),
        "latest_event_label": existing_data.get("latest_event_label"),
        "latest_event_at": existing_data.get("latest_event_at"),
        "latest_event_confidence": existing_data.get("latest_event_confidence"),
    }
    publish_runtime_state(initial_payload)

    if not os.path.exists(args.model_path):
        publish_runtime_state(
            {
                **base_payload,
                "session_active": session_state["active"],
                "camera_active": False,
                "monitor_state": "failed",
                "camera_error": f"Model not found at {args.model_path}",
            }
        )
        print(f"[DRIVER-AI] Model not found at {args.model_path}")
        sys.exit(1)

    def on_snapshot(doc_snapshot, changes, read_time):
        for doc in doc_snapshot:
            if not doc.exists:
                continue
            session_state["active"] = bool(
                (doc.to_dict() or {}).get("session_active", False)
            )

    doc_watch = doc_ref.on_snapshot(on_snapshot)

    try:
        model = YOLO(args.model_path)
    except Exception as exc:
        publish_runtime_state(
            {
                **base_payload,
                "session_active": session_state["active"],
                "camera_active": False,
                "monitor_state": "failed",
                "camera_error": f"Failed to load YOLO model: {exc}",
            }
        )
        print(f"[DRIVER-AI] Failed to load YOLO model: {exc}")
        doc_watch.unsubscribe()
        sys.exit(1)

    cap: cv2.VideoCapture | None = None
    last_event_time = {
        "yawn": 0.0,
        "usephone": 0.0,
        "drowsiness": 0.0,
    }
    detection_start_time = {
        "yawn": None,
        "usephone": None,
        "drowsiness": None,
    }
    cooldown_seconds = 5
    detection_required_seconds = 1
    last_camera_error: str | None = None
    last_session_mode: str | None = None

    print(f"[DRIVER-AI] Driver behavior monitor initialized for {driver_email}.")

    try:
        while not _stop_requested(args.stop_signal_path):
            if not session_state["active"]:
                if cap is not None and cap.isOpened():
                    cap.release()
                    cap = None
                if preview_open:
                    _close_preview_window(preview_open)
                    preview_open = False
                if last_session_mode != "standby":
                    publish_runtime_state(
                        {
                            **base_payload,
                            "session_active": False,
                            "camera_active": False,
                            "monitor_state": "standby",
                            "camera_error": None,
                            "ai_preview_mode": preview_mode,
                        }
                    )
                    last_session_mode = "standby"
                time.sleep(0.5)
                continue

            if cap is None or not cap.isOpened():
                if last_session_mode != "camera_opening":
                    publish_runtime_state(
                        {
                            **base_payload,
                            "session_active": True,
                            "camera_active": False,
                            "monitor_state": "camera_opening",
                            "camera_error": None,
                            "ai_preview_mode": preview_mode,
                        }
                    )
                    last_session_mode = "camera_opening"

                cap = _open_camera()
                if cap is None or not cap.isOpened():
                    last_camera_error = (
                        "Unable to access camera 0. Check whether another app already uses it."
                    )
                    publish_runtime_state(
                        {
                            **base_payload,
                            "session_active": True,
                            "camera_active": False,
                            "monitor_state": "camera_unavailable",
                            "camera_error": last_camera_error,
                            "ai_preview_mode": preview_mode,
                        }
                    )
                    last_session_mode = "camera_unavailable"
                    time.sleep(1.0)
                    continue

                if preview_requested and not preview_open:
                    preview_open = _prepare_preview_window(preview_requested)
                    if not preview_open:
                        preview_mode = "headless"
                publish_runtime_state(
                    {
                        **base_payload,
                        "session_active": True,
                        "camera_active": True,
                        "monitor_state": "monitoring",
                        "camera_error": None,
                        "ai_preview_mode": preview_mode,
                    }
                )
                last_session_mode = "monitoring"
                last_camera_error = None

            ret, frame = cap.read()
            if not ret:
                if cap is not None:
                    cap.release()
                    cap = None
                last_camera_error = "Camera frame could not be read. Retrying camera initialization."
                publish_runtime_state(
                    {
                        **base_payload,
                        "session_active": True,
                        "camera_active": False,
                        "monitor_state": "camera_unavailable",
                        "camera_error": last_camera_error,
                        "ai_preview_mode": preview_mode,
                    }
                )
                last_session_mode = "camera_unavailable"
                time.sleep(0.5)
                continue

            try:
                results = model(frame, verbose=False)
            except Exception as exc:
                publish_runtime_state(
                    {
                        **base_payload,
                        "session_active": True,
                        "camera_active": True,
                        "monitor_state": "failed",
                        "camera_error": f"Inference failed: {exc}",
                        "ai_preview_mode": preview_mode,
                    }
                )
                print(f"[DRIVER-AI] Inference failed: {exc}")
                time.sleep(0.5)
                continue

            found_events = {
                "yawn": False,
                "usephone": False,
                "drowsiness": False,
            }
            event_confidence = {
                "yawn": 0.0,
                "usephone": 0.0,
                "drowsiness": 0.0,
            }

            for result in results:
                boxes = result.boxes
                if boxes is None:
                    continue
                for box in boxes:
                    cls_id = int(box.cls[0])
                    confidence = float(box.conf[0])
                    if confidence < 0.5:
                        continue

                    class_name = str(result.names[cls_id]).lower().replace(" ", "")
                    if "yawn" in class_name:
                        found_events["yawn"] = True
                        event_confidence["yawn"] = max(event_confidence["yawn"], confidence)
                    elif "usephone" in class_name or "phone" in class_name:
                        found_events["usephone"] = True
                        event_confidence["usephone"] = max(
                            event_confidence["usephone"], confidence
                        )
                    elif "drows" in class_name:
                        found_events["drowsiness"] = True
                        event_confidence["drowsiness"] = max(
                            event_confidence["drowsiness"], confidence
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

            if (
                detection_start_time["usephone"] is not None
                and current_time - detection_start_time["usephone"]
                >= detection_required_seconds
            ):
                event_trigger = "usephone"
                detected_text = "Phone use detected"
            elif (
                detection_start_time["drowsiness"] is not None
                and current_time - detection_start_time["drowsiness"]
                >= detection_required_seconds
            ):
                event_trigger = "drowsiness"
                detected_text = "Drowsiness detected"
            elif (
                detection_start_time["yawn"] is not None
                and current_time - detection_start_time["yawn"]
                >= detection_required_seconds
            ):
                event_trigger = "yawn"
                detected_text = "Yawn detected"

            if event_trigger:
                cv2.putText(
                    frame,
                    detected_text,
                    (36, 48),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.9,
                    (0, 0, 255),
                    2,
                    cv2.LINE_AA,
                )

                if current_time - last_event_time[event_trigger] > cooldown_seconds:
                    try:
                        doc = doc_ref.get(timeout=FIRESTORE_TIMEOUT_SECONDS)
                        data = doc.to_dict() if doc.exists else {}
                        score = int(data.get("safety_score", 100) or 100)
                        yawn_count = int(
                            data.get("number_of_yawn", data.get("number_of_ywan", 0))
                            or 0
                        )
                        phone_count = int(data.get("number_of_usephone", 0) or 0)
                        drowsiness_count = int(data.get("number_of_drowsiness", 0) or 0)

                        updates = {
                            **base_payload,
                            "session_active": True,
                            "camera_active": True,
                            "monitor_state": "monitoring",
                            "camera_error": None,
                            "ai_preview_mode": preview_mode,
                            "latest_event_type": event_trigger,
                            "latest_event_label": detected_text,
                            "latest_event_at": _now_iso(),
                            "latest_event_confidence": round(
                                event_confidence[event_trigger],
                                4,
                            ),
                        }
                        if event_trigger == "yawn":
                            yawn_count += 1
                            updates["number_of_yawn"] = yawn_count
                            updates["safety_score"] = max(score - 1, 0)
                        elif event_trigger == "usephone":
                            phone_count += 1
                            updates["number_of_usephone"] = phone_count
                            updates["safety_score"] = max(score - 2, 0)
                        elif event_trigger == "drowsiness":
                            drowsiness_count += 1
                            updates["number_of_drowsiness"] = drowsiness_count
                            updates["safety_score"] = max(score - 5, 0)

                        updates.setdefault("number_of_yawn", yawn_count)
                        updates.setdefault("number_of_usephone", phone_count)
                        updates.setdefault("number_of_drowsiness", drowsiness_count)

                        publish_runtime_state(updates)
                        print(
                            "[DRIVER-AI] Logged event for "
                            f"{driver_email}: {detected_text} | score={updates['safety_score']}"
                        )
                        detection_start_time[event_trigger] = None
                        last_event_time[event_trigger] = current_time
                    except Exception as exc:
                        print(f"[DRIVER-AI] Error updating Firestore: {exc}")

            if preview_open:
                try:
                    cv2.imshow(WINDOW_NAME, frame)
                    key = cv2.waitKey(1) & 0xFF
                    if key in {27, ord("q"), ord("Q")}:
                        preview_requested = False
                        _close_preview_window(preview_open)
                        preview_open = False
                        preview_mode = "headless"
                        publish_runtime_state(
                            {
                                **base_payload,
                                "session_active": True,
                                "camera_active": True,
                                "monitor_state": "monitoring",
                                "camera_error": None,
                                "ai_preview_mode": preview_mode,
                            }
                        )
                except Exception as exc:
                    preview_open = False
                    preview_requested = False
                    preview_mode = "headless"
                    print(f"[DRIVER-AI] Preview fallback to headless mode: {exc}")
                    publish_runtime_state(
                        {
                            **base_payload,
                            "session_active": True,
                            "camera_active": True,
                            "monitor_state": "monitoring",
                            "camera_error": None,
                            "ai_preview_mode": preview_mode,
                        }
                    )
    finally:
        if cap is not None and cap.isOpened():
            cap.release()
        _close_preview_window(preview_open)
        try:
            doc_watch.unsubscribe()
        except Exception:
            pass
        publish_runtime_state(
            {
                **base_payload,
                "session_active": False,
                "camera_active": False,
                "monitor_state": "stopped",
                "camera_error": last_camera_error,
                "ai_preview_mode": preview_mode,
            }
        )


if __name__ == "__main__":
    main()

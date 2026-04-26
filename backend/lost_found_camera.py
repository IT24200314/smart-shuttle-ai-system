from __future__ import annotations

import argparse
import json
import os
import sys
import time
import uuid
from datetime import datetime
from typing import Any

import cv2


BACKEND_ROOT = os.path.dirname(os.path.abspath(__file__))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from services.lost_found_ai_service import detect_item_from_frame
from utils.firebase_config import db


WINDOW_NAME = "Lost And Found Monitor"
FIRESTORE_TIMEOUT_SECONDS = 3.0
POST_TRIP_WAKE_SECONDS = 10 * 60


def _now_iso() -> str:
    return datetime.now().isoformat()


def _today_date() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def _write_state_file(path: str, payload: dict) -> None:
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle)
    except OSError as exc:
        print(f"[LOST-FOUND-AI] Warning: unable to write state file '{path}': {exc}")


def _stop_requested(stop_signal_path: str) -> bool:
    return bool(stop_signal_path) and os.path.exists(stop_signal_path)


def _prepare_preview_window(preview_requested: bool) -> bool:
    if not preview_requested:
        print("[LOST-FOUND-AI] Preview disabled. Running in headless mode.")
        return False

    if sys.platform != "win32" and not os.environ.get("DISPLAY"):
        print("[LOST-FOUND-AI] Preview fallback to headless mode (no display detected).")
        return False

    try:
        cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(WINDOW_NAME, 960, 540)
        print("[LOST-FOUND-AI] Preview window opened.")
        return True
    except Exception as exc:
        print(f"[LOST-FOUND-AI] Preview fallback to headless mode: {exc}")
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


def _open_camera(camera_source: str) -> cv2.VideoCapture | None:
    source = camera_source.strip()
    capture_candidates: list[cv2.VideoCapture] = []

    if source:
        if source.isdigit():
            capture_candidates.append(cv2.VideoCapture(int(source)))
        else:
            capture_candidates.append(cv2.VideoCapture(source))
    else:
        if sys.platform == "win32":
            capture_candidates.append(cv2.VideoCapture(0, cv2.CAP_DSHOW))
            capture_candidates.append(cv2.VideoCapture(0))
        else:
            capture_candidates.append(cv2.VideoCapture(0))

    for cap in capture_candidates:
        if cap is not None and cap.isOpened():
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
            return cap
        if cap is not None:
            cap.release()
    return None


def _safe_int(value, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _is_session_end_state(*, status: str, ai_state: str) -> bool:
    normalized_status = status.strip().lower()
    normalized_ai_state = ai_state.strip().lower()
    return normalized_status in {"idle", "ended", "completed", "inactive"} or normalized_ai_state in {
        "stopped",
        "idle",
        "completed",
    }


def _read_live_status_snapshot(bus_id: str) -> dict | None:
    if db is None:
        return None

    try:
        live_doc: Any = db.collection("LIVE-STATUS").document(bus_id).get(
            timeout=FIRESTORE_TIMEOUT_SECONDS
        )
        if not live_doc.exists:
            return None
        data = live_doc.to_dict() or {}

        ai_state = str(data.get("ai_state") or "").strip().lower()
        status = str(data.get("status") or "").strip().lower()
        if ai_state in {"", "starting", "failed"}:
            return None

        passenger_count = None
        for key in (
            "passenger_count",
            "estimated_passenger_count_live",
            "estimated_passenger_count",
            "final_estimated_passenger_count",
        ):
            if data.get(key) is not None:
                passenger_count = max(_safe_int(data.get(key), 0), 0)
                break

        return {
            "passenger_count": passenger_count,
            "ai_state": ai_state,
            "status": status,
        }
    except Exception:
        return None


def _create_lost_item_record(
    *,
    bus_id: str,
    trip_id: str,
    item_type: str,
    confidence: float,
    model_path: str,
    passenger_count: int | None,
    ignore_passenger_count_gate: bool,
) -> str | None:
    if db is None:
        return None

    # Safety gate: never write detections while passengers are still onboard.
    if (not ignore_passenger_count_gate) and (
        passenger_count is None or passenger_count > 0
    ):
        print(
            "[LOST-FOUND-AI] Detection skipped because passenger count is not zero "
            f"(passenger_count={passenger_count})."
        )
        return None

    item_id = f"LF-AI-{bus_id}-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:4].upper()}"
    payload = {
        "type": item_type,
        "date_found": _today_date(),
        "status": "found",
        "busId": bus_id,
        "tripId": trip_id or None,
        "ai_confidence": round(confidence, 4),
        "ai_model_path": model_path,
        "detected_at": _now_iso(),
        "detected_from": "live_camera",
        "passenger_count_at_detection": passenger_count,
        "detection_gate": (
            "passenger_count_ignored"
            if ignore_passenger_count_gate
            else "passenger_count_zero"
        ),
    }
    try:
        db.collection("lost_found_items").document(item_id).set(
            payload,
            timeout=FIRESTORE_TIMEOUT_SECONDS,
        )
        return item_id
    except Exception as exc:
        print(f"[LOST-FOUND-AI] Failed to write lost_found_items/{item_id}: {exc}")
        return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bus_id", required=True, type=str)
    parser.add_argument("--trip_id", default="", type=str)
    parser.add_argument("--model_path", required=True, type=str)
    parser.add_argument("--stop_signal_path", required=True, type=str)
    parser.add_argument("--state_path", required=True, type=str)
    parser.add_argument("--camera_source", default="", type=str)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--confidence_threshold", default=0.45, type=float)
    parser.add_argument("--detection_cooldown_seconds", default=20.0, type=float)
    parser.add_argument("--max_runtime_seconds", default=0.0, type=float)
    parser.add_argument(
        "--ignore_passenger_count_gate",
        action="store_true",
        help="Allow detection writes even if passenger_count is not zero (testing only).",
    )
    args = parser.parse_args()

    if not args.bus_id.strip():
        print("[LOST-FOUND-AI] bus_id is required.")
        sys.exit(1)

    if db is None:
        print("[LOST-FOUND-AI] Failed to connect to Firebase.")
        sys.exit(1)

    preview_requested = not args.headless
    preview_open = False
    preview_mode = "preview" if preview_requested else "headless"
    last_signature: dict | None = None
    last_detection_at = 0.0
    session_started_at = time.time()
    post_trip_window_started_at: float | None = None
    saw_active_session = False

    live_ref = db.collection("LIVE-STATUS").document(args.bus_id)

    def publish_state(payload: dict) -> None:
        nonlocal last_signature
        if payload == last_signature:
            return

        last_signature = payload.copy()
        full_payload = {
            **payload,
            "updated_at": _now_iso(),
        }
        _write_state_file(args.state_path, full_payload)
        try:
            live_ref.set(
                {
                    "lost_found_ai_state": full_payload.get("monitor_state"),
                    "lost_found_camera_active": full_payload.get("camera_active", False),
                    "lost_found_last_type": full_payload.get("last_detected_type"),
                    "lost_found_last_confidence": full_payload.get(
                        "last_detected_confidence"
                    ),
                    "lost_found_last_detected_at": full_payload.get("last_detected_at"),
                    "lost_found_last_item_id": full_payload.get("last_detected_item_id"),
                    "lost_found_preview_mode": preview_mode,
                    "last_updated": _now_iso(),
                },
                merge=True,
                timeout=FIRESTORE_TIMEOUT_SECONDS,
            )
        except Exception as exc:
            print(f"[LOST-FOUND-AI] Warning: failed to update LIVE-STATUS: {exc}")

    base_payload = {
        "bus_id": args.bus_id,
        "trip_id": args.trip_id,
        "ai_model_path": args.model_path,
        "monitor_state": "starting",
        "camera_active": False,
        "last_detected_type": None,
        "last_detected_confidence": None,
        "last_detected_at": None,
        "last_detected_item_id": None,
    }
    publish_state(base_payload)

    cap: cv2.VideoCapture | None = None

    try:
        while not _stop_requested(args.stop_signal_path):
            if args.max_runtime_seconds > 0:
                elapsed = time.time() - session_started_at
                if elapsed >= args.max_runtime_seconds:
                    publish_state(
                        {
                            **base_payload,
                            "monitor_state": "post_trip_window_expired",
                            "camera_active": False,
                        }
                    )
                    break

            live_snapshot = _read_live_status_snapshot(args.bus_id)
            if live_snapshot is None:
                if cap is not None and cap.isOpened():
                    cap.release()
                    cap = None
                if preview_open:
                    _close_preview_window(preview_open)
                    preview_open = False
                publish_state(
                    {
                        **base_payload,
                        "monitor_state": "waiting_passenger_data",
                        "camera_active": False,
                    }
                )
                time.sleep(1.0)
                continue

            live_status = str(live_snapshot.get("status") or "").strip().lower()
            live_ai_state = str(live_snapshot.get("ai_state") or "").strip().lower()

            if live_status == "active":
                saw_active_session = True

            end_state_detected = saw_active_session and _is_session_end_state(
                status=live_status,
                ai_state=live_ai_state,
            )

            if not end_state_detected:
                if cap is not None and cap.isOpened():
                    cap.release()
                    cap = None
                if preview_open:
                    _close_preview_window(preview_open)
                    preview_open = False
                post_trip_window_started_at = None
                publish_state(
                    {
                        **base_payload,
                        "monitor_state": "sleeping_wait_session_end",
                        "camera_active": False,
                    }
                )
                time.sleep(1.0)
                continue

            if post_trip_window_started_at is None:
                post_trip_window_started_at = time.time()
                print(
                    "[LOST-FOUND-AI] End-session state detected. "
                    f"Keeping monitor awake for {POST_TRIP_WAKE_SECONDS} seconds."
                )

            if (time.time() - post_trip_window_started_at) >= POST_TRIP_WAKE_SECONDS:
                publish_state(
                    {
                        **base_payload,
                        "monitor_state": "post_trip_window_expired",
                        "camera_active": False,
                    }
                )
                break

            passenger_count = live_snapshot.get("passenger_count")
            if not args.ignore_passenger_count_gate and passenger_count is None:
                if cap is not None and cap.isOpened():
                    cap.release()
                    cap = None
                if preview_open:
                    _close_preview_window(preview_open)
                    preview_open = False
                publish_state(
                    {
                        **base_payload,
                        "monitor_state": "waiting_passenger_data",
                        "camera_active": False,
                    }
                )
                time.sleep(1.0)
                continue

            if (
                (not args.ignore_passenger_count_gate)
                and passenger_count is not None
                and passenger_count > 0
            ):
                if cap is not None and cap.isOpened():
                    cap.release()
                    cap = None
                if preview_open:
                    _close_preview_window(preview_open)
                    preview_open = False
                publish_state(
                    {
                        **base_payload,
                        "monitor_state": "sleeping_wait_passenger_zero",
                        "camera_active": False,
                    }
                )
                time.sleep(1.0)
                continue

            if cap is None or not cap.isOpened():
                cap = _open_camera(args.camera_source)
                if cap is None or not cap.isOpened():
                    publish_state(
                        {
                            **base_payload,
                            "monitor_state": "camera_unavailable",
                            "camera_active": False,
                        }
                    )
                    time.sleep(1.0)
                    continue

                if preview_requested and not preview_open:
                    preview_open = _prepare_preview_window(preview_requested)
                    if not preview_open:
                        preview_mode = "headless"

            ok, frame = cap.read()
            if not ok:
                cap.release()
                cap = None
                publish_state(
                    {
                        **base_payload,
                        "monitor_state": "camera_frame_error",
                        "camera_active": False,
                    }
                )
                time.sleep(0.4)
                continue

            detection = detect_item_from_frame(
                image=frame,
                confidence_threshold=args.confidence_threshold,
            )

            update_payload = {
                **base_payload,
                "monitor_state": "monitoring",
                "camera_active": True,
            }

            if detection["detected"]:
                now_ts = time.time()
                if now_ts - last_detection_at >= args.detection_cooldown_seconds:
                    item_id = _create_lost_item_record(
                        bus_id=args.bus_id,
                        trip_id=args.trip_id,
                        item_type=str(detection["item_type"]),
                        confidence=float(detection["confidence"]),
                        model_path=str(detection["model_path"]),
                        passenger_count=_safe_int(passenger_count, 0),
                        ignore_passenger_count_gate=args.ignore_passenger_count_gate,
                    )
                    if item_id:
                        last_detection_at = now_ts
                        update_payload.update(
                            {
                                "last_detected_type": str(detection["item_type"]),
                                "last_detected_confidence": round(
                                    float(detection["confidence"]),
                                    4,
                                ),
                                "last_detected_at": _now_iso(),
                                "last_detected_item_id": item_id,
                            }
                        )
                        print(
                            "[LOST-FOUND-AI] Detected item and saved to Firestore: "
                            f"type={detection['item_type']} item_id={item_id}"
                        )

            publish_state(update_payload)

            if preview_open:
                try:
                    cv2.imshow(WINDOW_NAME, frame)
                    key = cv2.waitKey(1) & 0xFF
                    if key in {27, ord("q"), ord("Q")}:
                        preview_requested = False
                        _close_preview_window(preview_open)
                        preview_open = False
                        preview_mode = "headless"
                except Exception:
                    preview_open = False
                    preview_requested = False
                    preview_mode = "headless"
    finally:
        if cap is not None and cap.isOpened():
            cap.release()
        _close_preview_window(preview_open)
        publish_state(
            {
                **base_payload,
                "monitor_state": "stopped",
                "camera_active": False,
            }
        )


if __name__ == "__main__":
    main()

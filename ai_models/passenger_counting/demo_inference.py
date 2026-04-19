from __future__ import annotations

import argparse
from collections import deque
import importlib.util
import json
import os
import sys
import threading
import time
from datetime import datetime
from pathlib import Path
from statistics import median

import cv2
import firebase_admin
from firebase_admin import credentials, firestore
from ultralytics import YOLO


BACKEND_ROOT = (Path(__file__).resolve().parents[2] / "backend").resolve()
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from utils.firebase_project_config import (  # noqa: E402
    assert_firebase_consistency,
    load_service_account_payload,
)


WINDOW_NAME = "Smart Shuttle AI Preview"
UPDATE_INTERVAL_SECONDS = 0.75
FIRESTORE_TIMEOUT_SECONDS = 3.0
TRACKER_NAME = "bytetrack.yaml"
MAX_TRACKING_DISTANCE = 80
MAX_MISSED_FRAMES = 12
VISIBLE_COUNT_WINDOW = 24
ESTIMATE_FLOOR_RATIO = 0.60
MIN_FILTERED_STABLE_SAMPLES = 3
FIRESTORE_WRITE_LOCK = threading.Lock()
FIRESTORE_WRITE_IN_FLIGHT = False


def _now_iso() -> str:
    return datetime.now().isoformat()


class SimpleCentroidTracker:
    def __init__(
        self,
        *,
        max_distance: int = MAX_TRACKING_DISTANCE,
        max_missed_frames: int = MAX_MISSED_FRAMES,
    ) -> None:
        self.max_distance = max_distance
        self.max_missed_frames = max_missed_frames
        self.next_track_id = 1
        self.tracks: dict[int, dict[str, int | tuple[int, int]]] = {}

    def update(self, detections: list[dict]) -> None:
        if not detections:
            self._age_unmatched_tracks(set())
            return

        matched_track_ids: set[int] = set()
        matched_detection_indexes: set[int] = set()
        candidate_pairs: list[tuple[float, int, int]] = []

        for track_id, track in self.tracks.items():
            track_center = track["center"]
            if not isinstance(track_center, tuple):
                continue
            for index, detection in enumerate(detections):
                detection_center = detection["center"]
                dx = track_center[0] - detection_center[0]
                dy = track_center[1] - detection_center[1]
                distance = ((dx * dx) + (dy * dy)) ** 0.5
                if distance <= self.max_distance:
                    candidate_pairs.append((distance, track_id, index))

        for _, track_id, index in sorted(candidate_pairs, key=lambda item: item[0]):
            if track_id in matched_track_ids or index in matched_detection_indexes:
                continue

            detection = detections[index]
            detection["track_id"] = track_id
            self.tracks[track_id] = {
                "center": detection["center"],
                "missed": 0,
            }
            matched_track_ids.add(track_id)
            matched_detection_indexes.add(index)

        for index, detection in enumerate(detections):
            if index in matched_detection_indexes:
                continue

            track_id = self.next_track_id
            self.next_track_id += 1
            detection["track_id"] = track_id
            self.tracks[track_id] = {
                "center": detection["center"],
                "missed": 0,
            }
            matched_track_ids.add(track_id)

        self._age_unmatched_tracks(matched_track_ids)

    def _age_unmatched_tracks(self, matched_track_ids: set[int]) -> None:
        stale_track_ids = []
        for track_id, track in self.tracks.items():
            if track_id in matched_track_ids:
                continue

            missed_frames = int(track.get("missed", 0)) + 1
            track["missed"] = missed_frames
            if missed_frames > self.max_missed_frames:
                stale_track_ids.append(track_id)

        for stale_track_id in stale_track_ids:
            self.tracks.pop(stale_track_id, None)


def initialize_firebase():
    try:
        report = assert_firebase_consistency()
        key_path, cert_dict = load_service_account_payload()
        if not firebase_admin._apps:
            print(
                "[FLOW] Passenger counting Firebase project verified: "
                f"{report['expected_project_id']}"
            )
            print(f"[FLOW] Using Firebase service account file: {key_path}")
            cred = credentials.Certificate(cert_dict)
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as exc:
        print(f"[FLOW] Error initializing Firebase: {exc}")
        return None


def _write_state_file(path: str, payload: dict) -> None:
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle)
    except OSError as exc:
        print(f"[FLOW] Warning: failed to write AI state file '{path}': {exc}")


def _safe_median(values: list[int] | deque[int]) -> int:
    filtered_values = [int(value) for value in values if value is not None]
    if not filtered_values:
        return 0
    return int(round(median(filtered_values)))


def _estimate_passenger_count(
    stable_samples: list[int],
    peak_visible_count: int,
) -> int:
    valid_samples = [sample for sample in stable_samples if sample > 0]
    if not valid_samples:
        return 0

    peak = max(peak_visible_count, max(valid_samples))
    floor = max(1, int(round(peak * ESTIMATE_FLOOR_RATIO)))
    filtered_samples = [sample for sample in valid_samples if sample >= floor]

    if len(filtered_samples) < min(MIN_FILTERED_STABLE_SAMPLES, len(valid_samples)):
        filtered_samples = valid_samples

    return _safe_median(filtered_samples)


def _publish_runtime_state(
    *,
    db_client,
    bus_id: str,
    state_path: str,
    payload: dict,
) -> None:
    full_payload = {
        **payload,
        "last_updated": _now_iso(),
    }
    _write_state_file(state_path, full_payload)

    if db_client is None:
        return

    global FIRESTORE_WRITE_IN_FLIGHT
    with FIRESTORE_WRITE_LOCK:
        if FIRESTORE_WRITE_IN_FLIGHT:
            return
        FIRESTORE_WRITE_IN_FLIGHT = True

    def _firestore_worker() -> None:
        global FIRESTORE_WRITE_IN_FLIGHT
        try:
            db_client.collection("LIVE-STATUS").document(bus_id).set(
                full_payload,
                merge=True,
                timeout=FIRESTORE_TIMEOUT_SECONDS,
            )
        except Exception as exc:
            print(f"[FLOW] Warning: failed to update LIVE-STATUS/{bus_id}: {exc}")
        finally:
            with FIRESTORE_WRITE_LOCK:
                FIRESTORE_WRITE_IN_FLIGHT = False

    threading.Thread(target=_firestore_worker, daemon=True).start()


def _mark_failed(
    *,
    db_client,
    bus_id: str,
    state_path: str,
    message: str,
    preview_mode: str,
    fallback_counts: dict | None = None,
) -> None:
    print(message)
    fallback = fallback_counts or {}
    current_detected_count = int(fallback.get("current_detected_count", 0) or 0)
    peak_visible_count = int(fallback.get("peak_visible_count", 0) or 0)
    estimated_live = int(fallback.get("estimated_passenger_count_live", 0) or 0)
    final_estimated = int(
        fallback.get("final_estimated_passenger_count", estimated_live) or 0
    )
    _publish_runtime_state(
        db_client=db_client,
        bus_id=bus_id,
        state_path=state_path,
        payload={
            "ai_state": "failed",
            "status": "active",
            "current_detected_count": max(current_detected_count, 0),
            "peak_visible_count": max(peak_visible_count, 0),
            "estimated_passenger_count_live": max(estimated_live, 0),
            "final_estimated_passenger_count": max(final_estimated, 0),
            "estimated_passenger_count": max(final_estimated, 0),
            "passenger_count": max(final_estimated, 0),
            "ai_preview_mode": preview_mode,
            "ai_error": message,
        },
    )


def _stop_requested(stop_signal_path: str) -> bool:
    return bool(stop_signal_path) and os.path.exists(stop_signal_path)


def _bytetrack_available() -> bool:
    return importlib.util.find_spec("lap") is not None


def _prepare_preview_window(preview_requested: bool) -> bool:
    if not preview_requested:
        print("[FLOW] Preview window disabled. Running in headless mode.")
        return False

    if sys.platform != "win32" and not os.environ.get("DISPLAY"):
        print("[FLOW] Preview window fallback to headless mode (no display detected).")
        return False

    try:
        cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(WINDOW_NAME, 1280, 720)
        print("[FLOW] Preview window opened")
        return True
    except Exception as exc:
        print(f"[FLOW] Preview window fallback to headless mode: {exc}")
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
    print("[FLOW] Preview window closed")


def _draw_preview(
    *,
    frame,
    detections: list[dict],
    current_visible_count: int,
    peak_visible_count: int,
    estimated_passenger_count: int,
    ai_state: str,
    tracker_label: str,
):
    overlay = frame.copy()

    for detection in detections:
        x1, y1, x2, y2 = detection["bbox"]
        track_id = detection["track_id"]
        center = detection["center"]
        color = (0, 220, 120) if track_id is not None else (120, 180, 255)
        cv2.rectangle(overlay, (x1, y1), (x2, y2), color, 2)
        cv2.circle(overlay, center, 4, color, -1)

        label = (
            f"ID {track_id}"
            if track_id is not None
            else "Detect"
        )
        cv2.putText(
            overlay,
            label,
            (x1, max(20, y1 - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            color,
            2,
            cv2.LINE_AA,
        )

    status_label = "AI ACTIVE" if ai_state == "processing" else f"AI {ai_state.upper()}"
    cv2.rectangle(overlay, (8, 8), (470, 164), (20, 20, 20), -1)
    cv2.putText(
        overlay,
        status_label,
        (18, 40),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.95,
        (80, 255, 140) if ai_state == "processing" else (255, 255, 255),
        3,
        cv2.LINE_AA,
    )
    cv2.putText(
        overlay,
        f"Visible Now: {current_visible_count}",
        (18, 72),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )
    cv2.putText(
        overlay,
        f"Peak Visible: {peak_visible_count}",
        (18, 100),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )
    cv2.putText(
        overlay,
        f"Estimated Passenger Count: {estimated_passenger_count}",
        (18, 128),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )
    cv2.putText(
        overlay,
        f"Tracker: {tracker_label}",
        (18, 156),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (220, 220, 220),
        2,
        cv2.LINE_AA,
    )

    return overlay


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bus_id", required=True, type=str)
    parser.add_argument("--trip_id", required=True, type=str)
    parser.add_argument("--video_path", required=True, type=str)
    parser.add_argument("--model_path", required=True, type=str)
    parser.add_argument("--stop_signal_path", required=True, type=str)
    parser.add_argument("--state_path", required=True, type=str)
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()

    preview_requested = not args.headless
    preview_mode = "preview" if preview_requested else "headless"

    db_client = initialize_firebase()
    _publish_runtime_state(
        db_client=db_client,
        bus_id=args.bus_id,
        state_path=args.state_path,
        payload={
            "status": "active",
            "trip_id": args.trip_id,
            "ai_state": "starting",
            "current_detected_count": 0,
            "peak_visible_count": 0,
            "estimated_passenger_count_live": 0,
            "final_estimated_passenger_count": 0,
            "estimated_passenger_count": 0,
            "passenger_count": 0,
            "ai_preview_mode": preview_mode,
            "ai_model_path": args.model_path,
            "ai_video_path": args.video_path,
        },
    )

    if not os.path.exists(args.video_path):
        _mark_failed(
            db_client=db_client,
            bus_id=args.bus_id,
            state_path=args.state_path,
            message=f"[FLOW] Error: demo video not found at {args.video_path}",
            preview_mode=preview_mode,
            fallback_counts={
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
            },
        )
        sys.exit(1)

    if not os.path.exists(args.model_path):
        _mark_failed(
            db_client=db_client,
            bus_id=args.bus_id,
            state_path=args.state_path,
            message=f"[FLOW] Error: model not found at {args.model_path}",
            preview_mode=preview_mode,
            fallback_counts={
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
            },
        )
        sys.exit(1)

    print(f"[FLOW] AI inference started for bus {args.bus_id}")
    print(f"[FLOW] Demo video loaded: {args.video_path}")
    _publish_runtime_state(
        db_client=db_client,
        bus_id=args.bus_id,
        state_path=args.state_path,
        payload={
            "status": "active",
            "trip_id": args.trip_id,
            "ai_state": "loading-model",
            "current_detected_count": 0,
            "peak_visible_count": 0,
            "estimated_passenger_count_live": 0,
            "final_estimated_passenger_count": 0,
            "estimated_passenger_count": 0,
            "passenger_count": 0,
            "ai_preview_mode": preview_mode,
            "ai_model_path": args.model_path,
            "ai_video_path": args.video_path,
        },
    )
    if _stop_requested(args.stop_signal_path):
        print("[FLOW] Stop signal received before model loading started.")
        _publish_runtime_state(
            db_client=db_client,
            bus_id=args.bus_id,
            state_path=args.state_path,
            payload={
                "status": "active",
                "trip_id": args.trip_id,
                "ai_state": "stopped",
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
                "estimated_passenger_count": 0,
                "passenger_count": 0,
                "ai_preview_mode": preview_mode,
            },
        )
        return

    try:
        model = YOLO(args.model_path)
    except Exception as exc:
        _mark_failed(
            db_client=db_client,
            bus_id=args.bus_id,
            state_path=args.state_path,
            message=f"[FLOW] Failed to load YOLO model: {exc}",
            preview_mode=preview_mode,
            fallback_counts={
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
            },
        )
        sys.exit(1)

    cap = cv2.VideoCapture(args.video_path)
    if not cap.isOpened():
        _mark_failed(
            db_client=db_client,
            bus_id=args.bus_id,
            state_path=args.state_path,
            message=f"[FLOW] Failed to open demo video: {args.video_path}",
            preview_mode=preview_mode,
            fallback_counts={
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
            },
        )
        sys.exit(1)

    preview_open = _prepare_preview_window(preview_requested)
    if not preview_open and preview_requested:
        preview_mode = "headless"
        _publish_runtime_state(
            db_client=db_client,
            bus_id=args.bus_id,
            state_path=args.state_path,
            payload={
                "status": "active",
                "trip_id": args.trip_id,
                "ai_state": "processing",
                "current_detected_count": 0,
                "peak_visible_count": 0,
                    "estimated_passenger_count_live": 0,
                    "final_estimated_passenger_count": 0,
                "estimated_passenger_count": 0,
                "passenger_count": 0,
                "ai_preview_mode": preview_mode,
            },
        )

    tracking_enabled = True
    tracker_warning_logged = False
    centroid_tracker = SimpleCentroidTracker()
    seen_ids: set[int] = set()
    current_visible_count = 0
    peak_visible_count = 0
    estimated_passenger_count = 0
    last_update_at = 0.0
    frame_index = 0
    video_completed = False
    video_read_failed = False
    tracker_mode = "ByteTrack IDs"
    visible_count_window: deque[int] = deque(maxlen=VISIBLE_COUNT_WINDOW)
    stable_samples: list[int] = []
    last_logged_visible: int | None = None
    last_logged_live_estimate: int | None = None
    last_logged_peak: int | None = None
    last_runtime_counts = {
        "current_detected_count": 0,
        "peak_visible_count": 0,
        "estimated_passenger_count_live": 0,
        "final_estimated_passenger_count": 0,
    }

    if not _bytetrack_available():
        tracking_enabled = False
        tracker_mode = "Centroid fallback"
        print(
            "[FLOW] ByteTrack dependency 'lap' is unavailable. "
            "Falling back to centroid tracking."
        )

    try:
        while cap.isOpened():
            if _stop_requested(args.stop_signal_path):
                print("[FLOW] Stop signal detected by AI subprocess.")
                break

            ret, frame = cap.read()
            if not ret:
                if frame_index == 0:
                    video_read_failed = True
                    print("[FLOW] Corrupted or unreadable demo video stream detected.")
                else:
                    video_completed = True
                    print("[FLOW] Demo video ended.")
                break

            frame_index += 1
            detections: list[dict] = []
            current_visible_count = 0

            try:
                if tracking_enabled:
                    results = model.track(
                        frame,
                        persist=True,
                        classes=[0],
                        tracker=TRACKER_NAME,
                        verbose=False,
                    )
                else:
                    results = model(
                        frame,
                        classes=[0],
                        verbose=False,
                    )
            except Exception as exc:
                if tracking_enabled:
                    tracking_enabled = False
                    tracker_mode = "Centroid fallback"
                    print(
                        "[FLOW] Tracker failure detected. "
                        f"Falling back to centroid tracking: {exc}"
                    )
                    results = model(
                        frame,
                        classes=[0],
                        verbose=False,
                    )
                else:
                    print(f"[FLOW] Detection failure on frame {frame_index}: {exc}")
                    continue

            if results and results[0].boxes is not None:
                boxes = results[0].boxes
                xyxy_list = boxes.xyxy.cpu().tolist() if boxes.xyxy is not None else []
                cls_list = boxes.cls.cpu().tolist() if boxes.cls is not None else []
                id_list = boxes.id.int().cpu().tolist() if boxes.id is not None else []

                if tracking_enabled and boxes.id is None and not tracker_warning_logged:
                    tracker_mode = "Centroid fallback"
                    print(
                        "[FLOW] Tracker IDs unavailable for this frame. "
                        "Switching to centroid tracking for stable unique counting."
                    )
                    tracker_warning_logged = True

                for index, bbox in enumerate(xyxy_list):
                    cls_id = int(cls_list[index]) if index < len(cls_list) else 0
                    if cls_id != 0:
                        continue

                    x1, y1, x2, y2 = [int(value) for value in bbox]
                    center_x = int((x1 + x2) / 2)
                    center_y = int((y1 + y2) / 2)
                    detections.append(
                        {
                            "bbox": (x1, y1, x2, y2),
                            "center": (center_x, center_y),
                            "track_id": (
                                int(id_list[index])
                                if tracking_enabled and index < len(id_list)
                                else None
                            ),
                        }
                    )

            if detections and any(detection["track_id"] is None for detection in detections):
                centroid_tracker.update(detections)
                tracker_mode = "Centroid fallback"

            visible_track_ids = {
                int(detection["track_id"])
                for detection in detections
                if detection["track_id"] is not None
            }
            for detection in detections:
                track_id = detection["track_id"]
                if track_id is None:
                    continue

                seen_ids.add(track_id)
            current_visible_count = (
                len(visible_track_ids)
                if visible_track_ids
                else len(detections)
            )
            visible_count_window.append(current_visible_count)
            rolling_stable_visible = _safe_median(visible_count_window)
            peak_visible_count = max(peak_visible_count, rolling_stable_visible)
            provisional_samples = stable_samples.copy()
            if rolling_stable_visible > 0:
                provisional_samples.append(rolling_stable_visible)
            estimated_passenger_count = _estimate_passenger_count(
                provisional_samples,
                peak_visible_count,
            )

            ai_state = "processing"
            if not preview_open:
                preview_mode = "headless"

            now = time.time()
            if now - last_update_at >= UPDATE_INTERVAL_SECONDS:
                stable_visible_count = _safe_median(visible_count_window)
                stable_samples.append(stable_visible_count)
                peak_visible_count = max(peak_visible_count, stable_visible_count)
                estimated_passenger_count = _estimate_passenger_count(
                    stable_samples,
                    peak_visible_count,
                )
                if current_visible_count != last_logged_visible:
                    print(f"[FLOW] Visible count updated: {current_visible_count}")
                    last_logged_visible = current_visible_count
                if peak_visible_count != last_logged_peak:
                    print(f"[FLOW] Peak visible count updated: {peak_visible_count}")
                    last_logged_peak = peak_visible_count
                if estimated_passenger_count != last_logged_live_estimate:
                    print(
                        "[FLOW] Live estimate updated: "
                        f"{estimated_passenger_count}"
                    )
                    last_logged_live_estimate = estimated_passenger_count

                last_runtime_counts = {
                    "current_detected_count": current_visible_count,
                    "peak_visible_count": peak_visible_count,
                    "estimated_passenger_count_live": estimated_passenger_count,
                    "final_estimated_passenger_count": estimated_passenger_count,
                }

                _publish_runtime_state(
                    db_client=db_client,
                    bus_id=args.bus_id,
                    state_path=args.state_path,
                    payload={
                        "status": "active",
                        "trip_id": args.trip_id,
                        "ai_state": ai_state,
                        "current_detected_count": current_visible_count,
                        "peak_visible_count": peak_visible_count,
                        "estimated_passenger_count_live": estimated_passenger_count,
                        "final_estimated_passenger_count": estimated_passenger_count,
                        "estimated_passenger_count": estimated_passenger_count,
                        "passenger_count": estimated_passenger_count,
                        "ai_preview_mode": preview_mode,
                        "tracked_ids_seen": len(seen_ids),
                        "tracker_mode": tracker_mode,
                        "stable_sample_count": len(stable_samples),
                    },
                )
                last_update_at = now

            if preview_open:
                preview_frame = _draw_preview(
                    frame=frame,
                    detections=detections,
                    current_visible_count=current_visible_count,
                    peak_visible_count=peak_visible_count,
                    estimated_passenger_count=estimated_passenger_count,
                    ai_state=ai_state,
                    tracker_label=tracker_mode,
                )
                try:
                    cv2.imshow(WINDOW_NAME, preview_frame)
                    key = cv2.waitKey(1) & 0xFF
                    if key in {27, ord("q"), ord("Q")}:
                        print("[FLOW] Preview window requested exit.")
                        break
                except Exception as exc:
                    preview_open = False
                    preview_mode = "headless"
                    print(f"[FLOW] Preview window fallback to headless mode: {exc}")

        final_state = "completed" if video_completed else "stopped"
        final_stable_visible = _safe_median(visible_count_window)
        if final_stable_visible > 0:
            stable_samples.append(final_stable_visible)
            peak_visible_count = max(peak_visible_count, final_stable_visible)
        final_estimated_passenger_count = _estimate_passenger_count(
            stable_samples,
            peak_visible_count,
        )
        last_runtime_counts = {
            "current_detected_count": current_visible_count,
            "peak_visible_count": peak_visible_count,
            "estimated_passenger_count_live": final_estimated_passenger_count,
            "final_estimated_passenger_count": final_estimated_passenger_count,
        }

        if video_read_failed:
            _mark_failed(
                db_client=db_client,
                bus_id=args.bus_id,
                state_path=args.state_path,
                message=(
                    "[FLOW] Error: demo video stream is corrupted or unreadable. "
                    "Preserving the last valid estimated count."
                ),
                preview_mode=preview_mode,
                fallback_counts=last_runtime_counts,
            )
        else:
            _publish_runtime_state(
                db_client=db_client,
                bus_id=args.bus_id,
                state_path=args.state_path,
                payload={
                    "status": "active",
                    "trip_id": args.trip_id,
                    "ai_state": final_state,
                    "current_detected_count": 0,
                    "peak_visible_count": peak_visible_count,
                    "estimated_passenger_count_live": final_estimated_passenger_count,
                    "final_estimated_passenger_count": final_estimated_passenger_count,
                    "estimated_passenger_count": final_estimated_passenger_count,
                    "passenger_count": final_estimated_passenger_count,
                    "ai_preview_mode": preview_mode,
                    "tracked_ids_seen": len(seen_ids),
                    "tracker_mode": tracker_mode,
                    "stable_sample_count": len(stable_samples),
                },
            )
            print(
                "[FLOW] Final estimated passenger count saved: "
                f"{final_estimated_passenger_count}"
            )
    except Exception as exc:
        _mark_failed(
            db_client=db_client,
            bus_id=args.bus_id,
            state_path=args.state_path,
            message=f"[FLOW] AI inference crashed unexpectedly: {exc}",
            preview_mode=preview_mode,
            fallback_counts=last_runtime_counts,
        )
        raise
    finally:
        cap.release()
        _close_preview_window(preview_open)


if __name__ == "__main__":
    main()

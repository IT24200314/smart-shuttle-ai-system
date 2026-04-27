from __future__ import annotations

import argparse
import sys
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

import cv2


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = PROJECT_ROOT / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

try:
    from ultralytics import YOLO
except Exception as exc:  # pragma: no cover - runtime dependency guard
    YOLO = None
    YOLO_IMPORT_ERROR = exc
else:
    YOLO_IMPORT_ERROR = None

try:
    from utils.firebase_config import db
except Exception as exc:  # pragma: no cover - runtime dependency guard
    db = None
    FIREBASE_IMPORT_ERROR = exc
else:
    FIREBASE_IMPORT_ERROR = None


RELEVANT_KEYWORDS = {
    "bag",
    "backpack",
    "handbag",
    "suitcase",
    "laptop bag",
    "bottle",
    "laptop",
    "umbrella",
    "book",
    "cell phone",
    "phone",
    "wallet",
    "purse",
}


def _log(message: str) -> None:
    try:
        print(message, flush=True)
    except OSError:
        pass


def _now_iso() -> str:
    return datetime.now().isoformat()


def _normalize_label(label: str) -> str:
    return " ".join(label.replace("_", " ").replace("-", " ").lower().split())


def _is_relevant(label: str) -> bool:
    normalized = _normalize_label(label)
    return any(keyword in normalized for keyword in RELEVANT_KEYWORDS)


def _display_name(label: str) -> str:
    normalized = _normalize_label(label)
    if normalized == "handbag":
        normalized = "bag"
    if normalized == "suitcase":
        normalized = "luggage bag"
    return normalized.title()


def _safe_doc_id(bus_id: str | None, trip_id: str | None, label: str) -> str:
    prefix = trip_id or bus_id or f"DEMO-{datetime.now().strftime('%Y%m%d%H%M%S')}"
    raw = f"LF-{prefix}-{label}"
    safe = "".join(char if char.isalnum() else "-" for char in raw.upper())
    return "-".join(part for part in safe.split("-") if part)[:120]


def _build_item_payload(
    *,
    item_id: str,
    label: str,
    confidence: float,
    bus_id: str | None,
    trip_id: str | None,
) -> dict[str, Any]:
    now = _now_iso()
    item_name = _display_name(label)
    item_type = _normalize_label(label)
    return {
        "itemId": item_id,
        "itemName": item_name,
        "itemType": item_type,
        "confidence": round(float(confidence), 4),
        "busId": bus_id,
        "tripId": trip_id,
        "detectedAt": now,
        "source": "lost_found_ai_demo",
        "status": "available",
        "imageUrl": None,
        "claimedBy": None,
        "claimRequestId": None,
        "notes": f"Detected by Lost & Found AI demo as {item_name}.",
        "createdAt": now,
        "updatedAt": now,
        # Backward-compatible aliases used by the existing Flutter screens/seed data.
        "id": item_id,
        "name": item_name,
        "type": item_type,
        "description": f"AI detected {item_name} after trip completion.",
        "date_found": now[:10],
        "foundedAt": now[:10],
    }


def _save_detections(
    detections: dict[str, float],
    *,
    bus_id: str | None,
    trip_id: str | None,
) -> None:
    if db is None:
        _log(f"[LOST_FOUND_FLOW] Warning: Firestore unavailable: {FIREBASE_IMPORT_ERROR}")
        return

    if not detections:
        _log("[LOST_FOUND_FLOW] No relevant lost items detected in demo window")
        return

    for label, confidence in detections.items():
        item_id = _safe_doc_id(bus_id, trip_id, label)
        payload = _build_item_payload(
            item_id=item_id,
            label=label,
            confidence=confidence,
            bus_id=bus_id,
            trip_id=trip_id,
        )
        try:
            db.collection("lost_found_items").document(item_id).set(payload, merge=True)
            _log(
                "[LOST_FOUND_FLOW] Saved lost_found_items/"
                f"{item_id} item={payload['itemName']} confidence={payload['confidence']}"
            )
        except Exception as exc:
            _log(f"[LOST_FOUND_FLOW] Warning: failed to save {item_id}: {exc}")


def _draw_preview(frame, result, model_names) -> None:
    boxes = getattr(result, "boxes", None)
    if boxes is None:
        return

    for box in boxes:
        class_id = int(box.cls[0].item())
        confidence = float(box.conf[0].item())
        label = _normalize_label(str(model_names.get(class_id, class_id)))
        if not _is_relevant(label):
            continue
        x1, y1, x2, y2 = [int(value) for value in box.xyxy[0].tolist()]
        caption = f"{_display_name(label)} {confidence:.2f}"
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 220, 120), 2)
        cv2.rectangle(frame, (x1, max(y1 - 24, 0)), (x1 + 180, y1), (0, 220, 120), -1)
        cv2.putText(
            frame,
            caption,
            (x1 + 6, max(y1 - 7, 14)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (0, 0, 0),
            2,
            cv2.LINE_AA,
        )


def run_demo(args: argparse.Namespace) -> int:
    model_path = Path(args.model_path)
    video_path = Path(args.video_path)

    if YOLO is None:
        _log(f"[LOST_FOUND_FLOW] Warning: ultralytics import failed: {YOLO_IMPORT_ERROR}")
        return 0
    if not model_path.exists():
        _log(f"[LOST_FOUND_FLOW] Warning: model not found at {model_path}")
        return 0
    if not video_path.exists():
        _log(f"[LOST_FOUND_FLOW] Warning: demo video not found at {video_path}")
        return 0

    _log(f"[LOST_FOUND_FLOW] Loading lost item model: {model_path}")
    try:
        model = YOLO(str(model_path))
    except Exception as exc:
        _log(f"[LOST_FOUND_FLOW] Warning: failed to load YOLO model: {exc}")
        return 0

    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        _log(f"[LOST_FOUND_FLOW] Warning: unable to open demo video: {video_path}")
        return 0

    fps = capture.get(cv2.CAP_PROP_FPS) or 25
    frame_limit = (
        None
        if args.full_video
        else max(int(float(args.duration_seconds) * fps), 1)
    )
    stride = 1 if args.preview else max(int(fps // 2), 1)
    preview_delay_ms = max(int(1000 / fps), 1)
    detections: dict[str, float] = {}
    frame_index = 0

    _log(
        "[LOST_FOUND_FLOW] Processing demo video "
        f"for {'full video' if args.full_video else f'{args.duration_seconds} seconds'} "
        f"bus={args.bus_id} trip={args.trip_id}"
    )
    if args.preview:
        _log("[LOST_FOUND_FLOW] Opening Lost & Found AI preview window")
    try:
        while frame_limit is None or frame_index < frame_limit:
            ok, frame = capture.read()
            if not ok:
                break

            preview_frame = frame.copy() if args.preview else None
            if frame_index % stride == 0:
                results = model.predict(frame, conf=args.confidence, verbose=False)
                for result in results:
                    names = result.names or getattr(model, "names", {})
                    if preview_frame is not None:
                        _draw_preview(preview_frame, result, names)
                    boxes = getattr(result, "boxes", None)
                    if boxes is None:
                        continue
                    for box in boxes:
                        class_id = int(box.cls[0].item())
                        confidence = float(box.conf[0].item())
                        label = _normalize_label(str(names.get(class_id, class_id)))
                        if not _is_relevant(label):
                            continue
                        detections[label] = max(confidence, detections.get(label, 0.0))
                        _log(
                            f"[LOST_FOUND_FLOW] Detected {label} "
                            f"confidence={confidence:.2f}"
                        )
            elif preview_frame is not None:
                cv2.putText(
                    preview_frame,
                    "Lost & Found AI scanning...",
                    (20, 36),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (0, 220, 120),
                    2,
                    cv2.LINE_AA,
                )
            if preview_frame is not None:
                cv2.imshow("Lost & Found AI Demo", preview_frame)
                if cv2.waitKey(preview_delay_ms) & 0xFF == ord("q"):
                    _log("[LOST_FOUND_FLOW] Preview closed by user")
                    break
            frame_index += 1
    finally:
        capture.release()
        if args.preview:
            cv2.destroyAllWindows()

    _save_detections(detections, bus_id=args.bus_id, trip_id=args.trip_id)
    _log(
        "[LOST_FOUND_FLOW] Lost item detection finished "
        f"classes={len(detections)}"
    )
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Lost & Found demo inference")
    parser.add_argument("--bus_id", default=None)
    parser.add_argument("--trip_id", default=None)
    parser.add_argument(
        "--model_path",
        default=str(Path(__file__).resolve().parent / "best.pt"),
    )
    parser.add_argument(
        "--video_path",
        default=str(Path(__file__).resolve().parent / "demo" / "demo.mp4"),
    )
    parser.add_argument("--duration_seconds", type=float, default=60)
    parser.add_argument("--confidence", type=float, default=0.25)
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--full_video", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(run_demo(parse_args()))

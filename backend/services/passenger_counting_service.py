from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
from datetime import datetime
from pathlib import Path
from typing import Any

from utils.firebase_config import db


DEFAULT_STOP_TIMEOUT_SECONDS = 5.0
FIRESTORE_TIMEOUT_SECONDS = 3.0
AI_PREVIEW_ENABLED = True
AI_SESSION_LOCK = threading.Lock()
AI_SESSIONS: dict[str, dict[str, Any]] = {}


def _now_iso() -> str:
    return datetime.now().isoformat()


def _coerce_non_negative_int(value: Any) -> int:
    try:
        return max(int(value or 0), 0)
    except (TypeError, ValueError):
        return 0


def _project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _passenger_ai_root() -> Path:
    return _project_root() / "ai_models" / "passenger_counting"


def _session_control_root() -> Path:
    control_root = Path(tempfile.gettempdir()) / "smart_shuttle_ai_demo"
    control_root.mkdir(parents=True, exist_ok=True)
    return control_root


def _safe_bus_id(bus_id: str) -> str:
    return "".join(char if char.isalnum() else "_" for char in bus_id)


def _session_paths(bus_id: str) -> dict[str, str]:
    safe_bus_id = _safe_bus_id(bus_id)
    control_root = _session_control_root()
    return {
        "stop_signal_path": str(control_root / f"{safe_bus_id}.stop"),
        "state_path": str(control_root / f"{safe_bus_id}.json"),
    }


def _remove_file(path: str) -> None:
    try:
        if os.path.exists(path):
            os.remove(path)
    except OSError:
        pass


def _write_state_file(path: str, payload: dict[str, Any]) -> None:
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle)
    except OSError as exc:
        print(f"[FLOW] Warning: unable to write AI state file '{path}': {exc}")


def _read_state_file(path: str) -> dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {}


def _first_present_int(
    sources: list[dict[str, Any]],
    keys: list[str],
    default: int = 0,
) -> int:
    for source in sources:
        if not source:
            continue
        for key in keys:
            if key in source and source.get(key) is not None:
                return _coerce_non_negative_int(source.get(key))
    return default


def _update_live_status(bus_id: str, payload: dict[str, Any]) -> None:
    if db is None:
        print("[FLOW] Warning: Firestore is unavailable while updating LIVE-STATUS.")
        return

    full_payload = {
        **payload,
        "last_updated": _now_iso(),
    }

    def _worker() -> None:
        try:
            db.collection("LIVE-STATUS").document(bus_id).set(
                full_payload,
                merge=True,
                timeout=FIRESTORE_TIMEOUT_SECONDS,
            )
        except Exception as exc:
            print(f"[FLOW] Warning: failed to update LIVE-STATUS/{bus_id}: {exc}")

    threading.Thread(target=_worker, daemon=True).start()


def _existing_custom_model_candidates() -> list[Path]:
    passenger_root = _passenger_ai_root()
    preferred_paths = [
        passenger_root
        / "runs"
        / "detect"
        / "passenger_counting_fixed"
        / "weights"
        / "best.pt",
        passenger_root
        / "runs"
        / "detect"
        / "runs"
        / "passenger_counting_fixed"
        / "YOLOv8s"
        / "weights"
        / "best.pt",
    ]

    discovered_paths = list(passenger_root.glob("runs/**/weights/best.pt"))
    discovered_paths.extend(list(passenger_root.glob("models/**/weights/best.pt")))

    def _candidate_rank(path: Path) -> tuple[int, int, float, str]:
        normalized = str(path).replace("\\", "/").lower()
        custom_priority = 0 if "/runs/" in normalized else 1
        fixed_priority = 0 if "passenger_counting_fixed" in normalized else 1
        modified_score = -path.stat().st_mtime if path.exists() else float("inf")
        return (
            custom_priority,
            fixed_priority,
            modified_score,
            normalized,
        )

    discovered_paths = sorted(discovered_paths, key=_candidate_rank)

    unique_candidates: list[Path] = []
    seen = set()
    for candidate in [*preferred_paths, *discovered_paths]:
        resolved = candidate.resolve()
        if resolved in seen or not candidate.exists():
            continue
        seen.add(resolved)
        unique_candidates.append(candidate)
    return unique_candidates


def get_best_model_path() -> str:
    for custom_model in _existing_custom_model_candidates():
        return str(custom_model)

    passenger_root = _passenger_ai_root()
    fallback_candidates = [
        passenger_root / "yolo11m.pt",
        passenger_root / "yolo11s.pt",
        passenger_root / "yolov8s.pt",
    ]
    for fallback_model in fallback_candidates:
        if fallback_model.exists():
            return str(fallback_model)

    raise FileNotFoundError(
        "No passenger counting model could be found. "
        "Expected a trained best.pt or a fallback base weight."
    )


def get_demo_video_path() -> str:
    preferred_demo = _project_root() / "preprocessing" / "demo_video" / "demo.mp4"
    if preferred_demo.exists():
        return str(preferred_demo)

    demo_video_dir = _project_root() / "preprocessing" / "demo_video"
    for candidate in sorted(demo_video_dir.glob("*.mp4")):
        return str(candidate)

    raw_video_dir = _project_root() / "preprocessing" / "raw_videos"
    for candidate in sorted(raw_video_dir.glob("*.mp4")):
        return str(candidate)

    raise FileNotFoundError(
        "No prerecorded demo video was found. "
        "Expected preprocessing/demo_video/demo.mp4."
    )


def get_passenger_counting_runtime_config() -> dict[str, str]:
    inference_script = _passenger_ai_root() / "demo_inference.py"
    if not inference_script.exists():
        raise FileNotFoundError(
            f"Passenger counting inference script is missing at {inference_script}"
        )

    return {
        "python_executable": sys.executable,
        "inference_script": str(inference_script),
        "model_path": get_best_model_path(),
        "video_path": get_demo_video_path(),
    }


def _reconcile_finished_session(bus_id: str) -> dict[str, Any] | None:
    session = AI_SESSIONS.get(bus_id)
    if not session:
        return None

    process: subprocess.Popen[str] = session["process"]
    if process.poll() is None:
        return session

    AI_SESSIONS.pop(bus_id, None)
    return None


def _get_last_metrics(
    bus_id: str,
    live_status_data: dict[str, Any] | None = None,
) -> dict[str, int]:
    live_data = live_status_data or {}
    state_data = _read_state_file(_session_paths(bus_id)["state_path"])

    sources = [state_data, live_data]
    live_estimate = _first_present_int(
        sources,
        [
            "estimated_passenger_count_live",
            "estimated_passenger_count",
            "passenger_count",
            "total_passenger_count",
        ],
        default=0,
    )
    explicit_final = _first_present_int(
        sources,
        [
            "final_estimated_passenger_count",
            "estimated_passenger_count_final",
        ],
        default=0,
    )
    state_text = str(
        next(
            (
                source.get("ai_state")
                for source in sources
                if source and source.get("ai_state") is not None
            ),
            "",
        )
    ).lower()

    if explicit_final > 0:
        final_estimate = explicit_final
    elif state_text in {"stopped", "completed", "failed"}:
        final_estimate = live_estimate
    else:
        final_estimate = max(explicit_final, live_estimate)

    peak_candidates: list[int] = []
    for source in sources:
        if not source:
            continue
        peak_candidates.extend(
            [
                _coerce_non_negative_int(source.get("peak_visible_count")),
                _coerce_non_negative_int(source.get("estimated_passenger_count_live")),
                _coerce_non_negative_int(source.get("estimated_passenger_count")),
                _coerce_non_negative_int(source.get("passenger_count")),
                _coerce_non_negative_int(source.get("final_estimated_passenger_count")),
            ]
        )
    peak_visible_count = max(peak_candidates + [final_estimate, live_estimate], default=0)

    current_detected_count = _first_present_int(
        sources,
        ["current_detected_count"],
        default=0,
    )

    estimated_passenger_count = final_estimate if final_estimate > 0 else live_estimate

    return {
        "estimated_passenger_count_live": live_estimate,
        "final_estimated_passenger_count": final_estimate,
        "estimated_passenger_count": estimated_passenger_count,
        "passenger_count": estimated_passenger_count,
        "peak_visible_count": peak_visible_count,
        "current_detected_count": current_detected_count,
    }


class PassengerCountingSessionManager:
    """Owns the demo-video passenger counting runtime lifecycle."""

    def __init__(self, *, preview_enabled: bool = AI_PREVIEW_ENABLED) -> None:
        self.preview_enabled = preview_enabled

    def get_runtime_config(self) -> dict[str, str]:
        return get_passenger_counting_runtime_config()

    def get_last_metrics(
        self,
        bus_id: str,
        live_status_data: dict[str, Any] | None = None,
    ) -> dict[str, int]:
        return _get_last_metrics(bus_id, live_status_data)

    def get_last_count(
        self,
        bus_id: str,
        live_status_data: dict[str, Any] | None = None,
    ) -> int:
        return self.get_last_metrics(bus_id, live_status_data)[
            "estimated_passenger_count"
        ]

    def launch(
        self,
        *,
        bus_id: str,
        trip_id: str,
        preview_enabled: bool | None = None,
    ) -> dict[str, Any]:
        runtime = self.get_runtime_config()
        session_paths = _session_paths(bus_id)
        preview_requested = (
            self.preview_enabled if preview_enabled is None else preview_enabled
        )

        with AI_SESSION_LOCK:
            existing_session = _reconcile_finished_session(bus_id)
            if existing_session:
                raise RuntimeError(
                    f"A passenger counting session is already running for bus {bus_id}"
                )

            _remove_file(session_paths["stop_signal_path"])
            initial_state = {
                "bus_id": bus_id,
                "trip_id": trip_id,
                "ai_state": "starting",
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
                "estimated_passenger_count": 0,
                "passenger_count": 0,
                "preview_mode": "preview" if preview_requested else "headless",
                "model_path": runtime["model_path"],
                "video_path": runtime["video_path"],
                "last_updated": _now_iso(),
            }
            _write_state_file(session_paths["state_path"], initial_state)

            command = [
                runtime["python_executable"],
                "-u",
                runtime["inference_script"],
                "--bus_id",
                bus_id,
                "--trip_id",
                trip_id,
                "--video_path",
                runtime["video_path"],
                "--model_path",
                runtime["model_path"],
                "--stop_signal_path",
                session_paths["stop_signal_path"],
                "--state_path",
                session_paths["state_path"],
            ]
            if not preview_requested:
                command.append("--headless")

            process = subprocess.Popen(
                command,
                cwd=str(_project_root()),
            )
            AI_SESSIONS[bus_id] = {
                "process": process,
                "trip_id": trip_id,
                "preview_enabled": preview_requested,
                "model_path": runtime["model_path"],
                "video_path": runtime["video_path"],
                **session_paths,
            }

        print(
            f"[FLOW] Passenger counting subprocess launched for bus {bus_id} with PID {process.pid}."
        )
        print(f"[FLOW] Demo video path: {runtime['video_path']}")
        print(f"[FLOW] Model path: {runtime['model_path']}")
        _update_live_status(
            bus_id,
            {
                "status": "active",
                "trip_id": trip_id,
                "ai_state": "starting",
                "current_detected_count": 0,
                "peak_visible_count": 0,
                "estimated_passenger_count_live": 0,
                "final_estimated_passenger_count": 0,
                "estimated_passenger_count": 0,
                "passenger_count": 0,
                "ai_preview_mode": "preview" if preview_requested else "headless",
            },
        )

        return {
            "pid": process.pid,
            "trip_id": trip_id,
            "model_path": runtime["model_path"],
            "video_path": runtime["video_path"],
            "preview_enabled": preview_requested,
            "ai_state": "starting",
        }

    def stop(
        self,
        bus_id: str,
        timeout_seconds: float = DEFAULT_STOP_TIMEOUT_SECONDS,
    ) -> dict[str, Any]:
        session_paths = _session_paths(bus_id)
        state_path = session_paths["state_path"]
        stop_signal_path = session_paths["stop_signal_path"]

        with AI_SESSION_LOCK:
            session = _reconcile_finished_session(bus_id)

        if not session:
            metrics = self.get_last_metrics(bus_id)
            _update_live_status(
                bus_id,
                {
                    "ai_state": "stopped",
                    **metrics,
                },
            )
            print(
                f"[FLOW] End Session received for {bus_id}, but no active passenger counting subprocess was found."
            )
            return {
                "was_running": False,
                "stopped_gracefully": True,
                **metrics,
                "ai_state": "stopped",
            }

        process: subprocess.Popen[str] = session["process"]
        print(f"[FLOW] End Session received for passenger counting on {bus_id}.")
        _update_live_status(
            bus_id,
            {
                "ai_state": "stopping",
            },
        )

        try:
            Path(stop_signal_path).write_text(_now_iso(), encoding="utf-8")
        except OSError as exc:
            print(f"[FLOW] Warning: failed to create stop signal for {bus_id}: {exc}")

        stopped_gracefully = False
        if process.poll() is None:
            try:
                process.wait(timeout=timeout_seconds)
                stopped_gracefully = True
            except subprocess.TimeoutExpired:
                print(
                    f"[FLOW] Graceful stop timed out for {bus_id}. Terminating passenger counting subprocess."
                )

        metrics = self.get_last_metrics(bus_id)

        if process.poll() is None:
            try:
                process.terminate()
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                print(f"[FLOW] Force-killing passenger counting subprocess for {bus_id}.")
                process.kill()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    pass

        _update_live_status(
            bus_id,
            {
                "ai_state": "stopped",
                **metrics,
            },
        )

        with AI_SESSION_LOCK:
            AI_SESSIONS.pop(bus_id, None)

        _remove_file(stop_signal_path)
        _remove_file(state_path)
        print(f"[FLOW] Passenger counting subprocess stopped for bus {bus_id}.")
        return {
            "was_running": True,
            "stopped_gracefully": stopped_gracefully,
            **metrics,
            "ai_state": "stopped",
        }


passenger_counting_session_manager = PassengerCountingSessionManager()


def get_last_ai_metrics(
    bus_id: str,
    live_status_data: dict[str, Any] | None = None,
) -> dict[str, int]:
    return passenger_counting_session_manager.get_last_metrics(bus_id, live_status_data)


def get_last_ai_count(bus_id: str, live_status_data: dict[str, Any] | None = None) -> int:
    return passenger_counting_session_manager.get_last_count(bus_id, live_status_data)


def launch_ai_counting(
    *,
    bus_id: str,
    trip_id: str,
    preview_enabled: bool = AI_PREVIEW_ENABLED,
) -> dict[str, Any]:
    return passenger_counting_session_manager.launch(
        bus_id=bus_id,
        trip_id=trip_id,
        preview_enabled=preview_enabled,
    )


def stop_ai_counting(
    bus_id: str,
    timeout_seconds: float = DEFAULT_STOP_TIMEOUT_SECONDS,
) -> dict[str, Any]:
    return passenger_counting_session_manager.stop(
        bus_id,
        timeout_seconds=timeout_seconds,
    )

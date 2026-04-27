from __future__ import annotations

import subprocess
import sys
import threading
from pathlib import Path
from typing import Any


LOST_FOUND_LOCK = threading.Lock()
LOST_FOUND_PROCESSES: dict[str, subprocess.Popen] = {}
LOST_FOUND_LAUNCHED_KEYS: set[str] = set()


def _project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _lost_found_root() -> Path:
    return _project_root() / "ai_models" / "lost_and_found"


def _find_model_path() -> Path | None:
    lost_found_root = _lost_found_root()
    candidates = [
        lost_found_root / "best.pt",
        lost_found_root / "best (1).pt",
    ]
    candidates.extend(sorted(lost_found_root.glob("*.pt")))
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def launch_lost_found_ai(
    bus_id: str | None = None,
    trip_id: str | None = None,
    duration_seconds: int = 60,
    preview: bool = True,
) -> dict[str, Any]:
    """Launch the Lost & Found demo AI without blocking the FastAPI request."""

    root = _project_root()
    script_path = _lost_found_root() / "demo_inference.py"
    video_path = _lost_found_root() / "demo" / "demo.mp4"
    model_path = _find_model_path()

    launch_key = trip_id or bus_id or "lost-found-demo"

    print("[LOST_FOUND_FLOW] Launching lost and found AI")

    with LOST_FOUND_LOCK:
        existing_process = LOST_FOUND_PROCESSES.get(launch_key)
        if existing_process and existing_process.poll() is None:
            print(
                "[LOST_FOUND_FLOW] Lost and found AI is already running "
                f"for key={launch_key} pid={existing_process.pid}"
            )
            return {
                "started": True,
                "already_running": True,
                "pid": existing_process.pid,
                "bus_id": bus_id,
                "trip_id": trip_id,
            }
        LOST_FOUND_PROCESSES.pop(launch_key, None)
        if launch_key in LOST_FOUND_LAUNCHED_KEYS:
            print(
                "[LOST_FOUND_FLOW] Lost and found AI already launched "
                f"for key={launch_key}; skipping duplicate trigger"
            )
            return {
                "started": False,
                "already_launched": True,
                "bus_id": bus_id,
                "trip_id": trip_id,
            }

    if not script_path.exists():
        print(f"[LOST_FOUND_FLOW] Warning: demo script missing at {script_path}")
        return {"started": False, "reason": "script_missing", "script_path": str(script_path)}

    if model_path is None:
        print(
            "[LOST_FOUND_FLOW] Warning: lost item model missing. "
            f"Expected {(_lost_found_root() / 'best.pt')}."
        )
        return {"started": False, "reason": "model_missing", "model_path": None}

    if not video_path.exists():
        print(f"[LOST_FOUND_FLOW] Warning: demo video missing at {video_path}")
        return {"started": False, "reason": "video_missing", "video_path": str(video_path)}

    command = [
        sys.executable,
        "-u",
        str(script_path),
        "--model_path",
        str(model_path),
        "--video_path",
        str(video_path),
        "--duration_seconds",
        str(duration_seconds),
    ]
    if preview:
        command.append("--preview")
    if bus_id:
        command.extend(["--bus_id", bus_id])
    if trip_id:
        command.extend(["--trip_id", trip_id])

    try:
        process = subprocess.Popen(command, cwd=str(root))
    except Exception as exc:
        print(f"[LOST_FOUND_FLOW] Warning: failed to launch lost and found AI: {exc}")
        return {"started": False, "reason": "launch_failed", "error": str(exc)}

    with LOST_FOUND_LOCK:
        LOST_FOUND_PROCESSES[launch_key] = process
        LOST_FOUND_LAUNCHED_KEYS.add(launch_key)

    print(
        "[LOST_FOUND_FLOW] Lost item detection started "
        f"for bus={bus_id or 'unknown'} trip={trip_id or 'unknown'} pid={process.pid}"
    )
    return {
        "started": True,
        "pid": process.pid,
        "model_path": str(model_path),
        "video_path": str(video_path),
        "duration_seconds": duration_seconds,
        "preview": preview,
        "bus_id": bus_id,
        "trip_id": trip_id,
    }

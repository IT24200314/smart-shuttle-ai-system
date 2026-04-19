from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from utils.firebase_config import db


DEFAULT_STOP_TIMEOUT_SECONDS = 5.0
FIRESTORE_TIMEOUT_SECONDS = 3.0
DRIVER_BEHAVIOR_PREVIEW_ENABLED = True
DRIVER_BEHAVIOR_LOCK = threading.Lock()
DRIVER_BEHAVIOR_SESSIONS: dict[str, dict[str, Any]] = {}


def _now_iso() -> str:
    return datetime.now().isoformat()


def _normalize_driver_email(driver_email: str) -> str:
    return (driver_email or "").strip().lower()


def _project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _driver_camera_script() -> Path:
    return _project_root() / "backend" / "driver_camera.py"


def _driver_behavior_model_root() -> Path:
    return _project_root() / "ai_models" / "driver_behavior"


def _session_control_root() -> Path:
    control_root = Path(tempfile.gettempdir()) / "smart_shuttle_driver_behavior"
    control_root.mkdir(parents=True, exist_ok=True)
    return control_root


def _safe_driver_key(driver_email: str) -> str:
    normalized = _normalize_driver_email(driver_email)
    return "".join(char if char.isalnum() else "_" for char in normalized)


def _session_paths(driver_email: str) -> dict[str, str]:
    safe_driver_key = _safe_driver_key(driver_email)
    control_root = _session_control_root()
    return {
        "stop_signal_path": str(control_root / f"{safe_driver_key}.stop"),
        "state_path": str(control_root / f"{safe_driver_key}.json"),
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
        print(
            f"[DRIVER-AI] Warning: unable to write state file '{path}': {exc}"
        )


def _read_state_file(path: str) -> dict[str, Any]:
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {}


def _today_doc_id(driver_email: str) -> str:
    date_str = datetime.now().strftime("%Y-%m-%d")
    return f"{_normalize_driver_email(driver_email)}_{date_str}"


def _update_behavior_log(driver_email: str, payload: dict[str, Any]) -> None:
    if db is None:
        print("[DRIVER-AI] Warning: Firestore unavailable while updating behavior log.")
        return

    doc_ref = db.collection("driver_behavior_logs").document(_today_doc_id(driver_email))
    full_payload = {
        **payload,
        "updated_at": _now_iso(),
    }

    def _worker() -> None:
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

    threading.Thread(target=_worker, daemon=True).start()


def _existing_model_candidates() -> list[Path]:
    model_root = _driver_behavior_model_root()
    preferred = [
        model_root / "best.pt",
    ]
    discovered = list(model_root.glob("**/best.pt"))

    unique_candidates: list[Path] = []
    seen: set[Path] = set()
    for candidate in [*preferred, *sorted(discovered)]:
        resolved = candidate.resolve()
        if resolved in seen or not candidate.exists():
            continue
        seen.add(resolved)
        unique_candidates.append(candidate)
    return unique_candidates


def get_driver_behavior_model_path() -> str:
    for candidate in _existing_model_candidates():
        return str(candidate)

    raise FileNotFoundError(
        "No driver behavior model could be found. "
        "Expected ai_models/driver_behavior/best.pt."
    )


def get_driver_behavior_runtime_config() -> dict[str, str]:
    script_path = _driver_camera_script()
    if not script_path.exists():
        raise FileNotFoundError(
            f"Driver behavior runtime script is missing at {script_path}"
        )

    return {
        "python_executable": sys.executable,
        "script_path": str(script_path),
        "model_path": get_driver_behavior_model_path(),
    }


def _reconcile_finished_session(driver_email: str) -> dict[str, Any] | None:
    session = DRIVER_BEHAVIOR_SESSIONS.get(_normalize_driver_email(driver_email))
    if not session:
        return None

    process: subprocess.Popen[str] = session["process"]
    if process.poll() is None:
        return session

    DRIVER_BEHAVIOR_SESSIONS.pop(_normalize_driver_email(driver_email), None)
    return None


def _is_pid_running(pid: int | None) -> bool:
    if not pid or pid <= 0:
        return False

    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def _terminate_pid(pid: int) -> None:
    if not _is_pid_running(pid):
        return

    sigkill = getattr(signal, "SIGKILL", signal.SIGTERM)
    for sig in (signal.SIGTERM, sigkill):
        try:
            os.kill(pid, sig)
        except OSError:
            return
        time.sleep(0.4)
        if not _is_pid_running(pid):
            return


def _stop_stale_runtime(driver_email: str, grace_seconds: float = 2.0) -> None:
    session_paths = _session_paths(driver_email)
    state = _read_state_file(session_paths["state_path"])
    pid = int(state.get("pid", 0) or 0)
    if not _is_pid_running(pid):
        return

    try:
        Path(session_paths["stop_signal_path"]).write_text(_now_iso(), encoding="utf-8")
    except OSError:
        pass

    started = time.time()
    while time.time() - started < grace_seconds:
        if not _is_pid_running(pid):
            break
        time.sleep(0.2)

    if _is_pid_running(pid):
        _terminate_pid(pid)


def get_driver_behavior_state(driver_email: str) -> dict[str, Any]:
    return _read_state_file(_session_paths(driver_email)["state_path"])


class DriverBehaviorSessionManager:
    """Owns the laptop-camera driver behavior runtime lifecycle."""

    def __init__(
        self,
        *,
        preview_enabled: bool = DRIVER_BEHAVIOR_PREVIEW_ENABLED,
    ) -> None:
        self.preview_enabled = preview_enabled

    def get_runtime_config(self) -> dict[str, str]:
        return get_driver_behavior_runtime_config()

    def get_state(self, driver_email: str) -> dict[str, Any]:
        return get_driver_behavior_state(driver_email)

    def launch(
        self,
        *,
        driver_email: str,
        driver_id: str | None = None,
        driver_name: str | None = None,
        preview_enabled: bool | None = None,
    ) -> dict[str, Any]:
        return launch_driver_behavior_monitor(
            driver_email=driver_email,
            driver_id=driver_id,
            driver_name=driver_name,
            preview_enabled=(
                self.preview_enabled if preview_enabled is None else preview_enabled
            ),
        )

    def stop(
        self,
        driver_email: str,
        timeout_seconds: float = DEFAULT_STOP_TIMEOUT_SECONDS,
    ) -> dict[str, Any]:
        return stop_driver_behavior_monitor(
            driver_email,
            timeout_seconds=timeout_seconds,
        )


def launch_driver_behavior_monitor(
    *,
    driver_email: str,
    driver_id: str | None = None,
    driver_name: str | None = None,
    preview_enabled: bool = DRIVER_BEHAVIOR_PREVIEW_ENABLED,
) -> dict[str, Any]:
    normalized_email = _normalize_driver_email(driver_email)
    if not normalized_email:
        raise ValueError("driver_email is required to start driver behavior monitoring")

    runtime = get_driver_behavior_runtime_config()
    session_paths = _session_paths(normalized_email)

    with DRIVER_BEHAVIOR_LOCK:
        existing_session = _reconcile_finished_session(normalized_email)
        if existing_session:
            existing_state = _read_state_file(existing_session["state_path"])
            return {
                "pid": existing_session["process"].pid,
                "driver_email": normalized_email,
                "driver_id": driver_id,
                "driver_name": driver_name,
                "model_path": existing_session["model_path"],
                "preview_enabled": existing_session["preview_enabled"],
                "monitor_state": existing_state.get("monitor_state", "starting"),
                "camera_active": bool(existing_state.get("camera_active", False)),
                "already_running": True,
            }

        _stop_stale_runtime(normalized_email)
        _remove_file(session_paths["stop_signal_path"])

        initial_state = {
            "driver_email": normalized_email,
            "driver_id": driver_id,
            "driver_name": driver_name,
            "monitor_state": "starting",
            "camera_active": False,
            "preview_mode": "preview" if preview_enabled else "headless",
            "model_path": runtime["model_path"],
            "last_updated": _now_iso(),
        }
        _write_state_file(session_paths["state_path"], initial_state)

        command = [
            runtime["python_executable"],
            "-u",
            runtime["script_path"],
            "--driver_email",
            normalized_email,
            "--model_path",
            runtime["model_path"],
            "--stop_signal_path",
            session_paths["stop_signal_path"],
            "--state_path",
            session_paths["state_path"],
        ]
        if driver_id:
            command.extend(["--driver_id", driver_id])
        if driver_name:
            command.extend(["--driver_name", driver_name])
        if not preview_enabled:
            command.append("--headless")

        process = subprocess.Popen(
            command,
            cwd=str(_project_root()),
        )

        session_key = _normalize_driver_email(normalized_email)
        DRIVER_BEHAVIOR_SESSIONS[session_key] = {
            "process": process,
            "driver_email": normalized_email,
            "driver_id": driver_id,
            "driver_name": driver_name,
            "preview_enabled": preview_enabled,
            "model_path": runtime["model_path"],
            **session_paths,
        }

        initial_state["pid"] = process.pid
        _write_state_file(session_paths["state_path"], initial_state)

    print(
        "[DRIVER-AI] Driver behavior monitor launched for "
        f"{normalized_email} with PID {process.pid}."
    )
    _update_behavior_log(
        normalized_email,
        {
            "driver_id": driver_id,
            "driver_name": driver_name,
            "email": normalized_email,
            "monitor_state": "starting",
            "camera_active": False,
            "ai_model_path": runtime["model_path"],
            "ai_preview_mode": "preview" if preview_enabled else "headless",
        },
    )
    return {
        "pid": process.pid,
        "driver_email": normalized_email,
        "driver_id": driver_id,
        "driver_name": driver_name,
        "model_path": runtime["model_path"],
        "preview_enabled": preview_enabled,
        "monitor_state": "starting",
        "camera_active": False,
        "already_running": False,
    }


def stop_driver_behavior_monitor(
    driver_email: str,
    timeout_seconds: float = DEFAULT_STOP_TIMEOUT_SECONDS,
) -> dict[str, Any]:
    normalized_email = _normalize_driver_email(driver_email)
    if not normalized_email:
        return {
            "was_running": False,
            "stopped_gracefully": True,
            "monitor_state": "stopped",
            "camera_active": False,
        }

    session_paths = _session_paths(normalized_email)
    stop_signal_path = session_paths["stop_signal_path"]
    state_path = session_paths["state_path"]

    with DRIVER_BEHAVIOR_LOCK:
        session = _reconcile_finished_session(normalized_email)

    if not session:
        _stop_stale_runtime(normalized_email)
        state = _read_state_file(state_path)
        monitor_state = state.get("monitor_state", "stopped")
        if monitor_state != "stopped":
            monitor_state = "stopped"
        _update_behavior_log(
            normalized_email,
            {
                "session_active": False,
                "monitor_state": monitor_state,
                "camera_active": False,
                "camera_error": state.get("camera_error"),
            },
        )
        return {
            "was_running": False,
            "stopped_gracefully": True,
            "monitor_state": monitor_state,
            "camera_active": False,
        }

    process: subprocess.Popen[str] = session["process"]
    print(f"[DRIVER-AI] Stop requested for driver behavior monitor {normalized_email}.")
    _update_behavior_log(
        normalized_email,
        {
            "session_active": False,
            "monitor_state": "stopping",
            "camera_active": False,
        },
    )

    try:
        Path(stop_signal_path).write_text(_now_iso(), encoding="utf-8")
    except OSError as exc:
        print(
            f"[DRIVER-AI] Warning: failed to create stop signal for {normalized_email}: {exc}"
        )

    stopped_gracefully = False
    if process.poll() is None:
        try:
            process.wait(timeout=timeout_seconds)
            stopped_gracefully = True
        except subprocess.TimeoutExpired:
            print(
                "[DRIVER-AI] Graceful stop timed out for "
                f"{normalized_email}. Terminating runtime."
            )

    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass

    state = _read_state_file(state_path)
    final_state = state.get("monitor_state", "stopped")
    if final_state == "stopping":
        final_state = "stopped"

    _update_behavior_log(
        normalized_email,
        {
            "session_active": False,
            "monitor_state": final_state,
            "camera_active": False,
            "camera_error": state.get("camera_error"),
        },
    )

    with DRIVER_BEHAVIOR_LOCK:
        DRIVER_BEHAVIOR_SESSIONS.pop(normalized_email, None)

    _remove_file(stop_signal_path)
    print(f"[DRIVER-AI] Driver behavior monitor stopped for {normalized_email}.")
    return {
        "was_running": True,
        "stopped_gracefully": stopped_gracefully,
        "monitor_state": final_state,
        "camera_active": False,
    }


driver_behavior_session_manager = DriverBehaviorSessionManager()

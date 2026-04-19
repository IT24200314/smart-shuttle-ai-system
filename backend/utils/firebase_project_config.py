from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any


class FirebaseConsistencyError(RuntimeError):
    """Raised when the repo's Firebase config sources disagree."""


_DART_OPTION_BLOCK = re.compile(
    r"static const FirebaseOptions (?P<platform>\w+) = FirebaseOptions\((?P<body>.*?)\);",
    re.DOTALL,
)
_DART_OPTION_FIELD = re.compile(r"(\w+):\s*'([^']*)'")
_DART_FIELD_MAP = {
    "apiKey": "api_key",
    "appId": "app_id",
    "messagingSenderId": "messaging_sender_id",
    "projectId": "project_id",
    "authDomain": "auth_domain",
    "storageBucket": "storage_bucket",
}
_LABELS = {
    "project_id": "Project ID",
    "project_number": "Project Number",
    "api_key": "API Key",
    "app_id": "App ID",
    "messaging_sender_id": "Messaging Sender ID",
    "auth_domain": "Auth Domain",
    "storage_bucket": "Storage Bucket",
    "package_name": "Android Package Name",
    "client_email_domain": "Service Account Domain",
}


def project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def firebase_manifest_path() -> Path:
    return (
        project_root()
        / "frontend"
        / "smart_shuttle_app"
        / "assets"
        / "config"
        / "firebase_project_manifest.json"
    )


def firebase_options_path() -> Path:
    return (
        project_root()
        / "frontend"
        / "smart_shuttle_app"
        / "lib"
        / "firebase_options.dart"
    )


def google_services_path() -> Path:
    return (
        project_root()
        / "frontend"
        / "smart_shuttle_app"
        / "android"
        / "app"
        / "google-services.json"
    )


def backend_database_dir() -> Path:
    return project_root() / "backend" / "database"


def _load_json_file(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise FirebaseConsistencyError(f"Required Firebase config file is missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise FirebaseConsistencyError(f"Invalid JSON in Firebase config file: {path}") from exc


def load_manifest() -> dict[str, Any]:
    return _load_json_file(firebase_manifest_path())


def _resolve_repo_path(value: str | None) -> Path | None:
    if not value:
        return None

    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = project_root() / candidate
    return candidate.resolve()


def service_account_candidates() -> list[Path]:
    manifest = load_manifest()
    service_account = dict(manifest.get("service_account") or {})
    env_var = str(
        service_account.get("env_var", "SMART_SHUTTLE_FIREBASE_SERVICE_ACCOUNT")
    )

    candidates: list[Path] = []
    env_value = os.getenv(env_var, "").strip()
    env_path = _resolve_repo_path(env_value)
    if env_path is not None:
        candidates.append(env_path)

    for key in ("local_override_path",):
        candidate = _resolve_repo_path(str(service_account.get(key) or "").strip())
        if candidate is not None:
            candidates.append(candidate)

    unique_candidates: list[Path] = []
    seen: set[Path] = set()
    for candidate in candidates:
        if candidate in seen:
            continue
        seen.add(candidate)
        unique_candidates.append(candidate)
    return unique_candidates


def describe_service_account_source(path: Path) -> str:
    manifest = load_manifest()
    service_account = dict(manifest.get("service_account") or {})
    env_var = str(
        service_account.get("env_var", "SMART_SHUTTLE_FIREBASE_SERVICE_ACCOUNT")
    )
    env_path = _resolve_repo_path(os.getenv(env_var, "").strip())
    local_override = _resolve_repo_path(
        str(service_account.get("local_override_path") or "").strip()
    )

    if env_path is not None and env_path == path:
        return f"env:{env_var}"
    if local_override is not None and local_override == path:
        return "local_override_path"
    return "custom"


def resolve_service_account_path() -> Path:
    candidates = service_account_candidates()
    for candidate in candidates:
        if candidate.exists():
            return candidate

    checked = ", ".join(str(path) for path in candidates) or "<no candidates>"
    raise FirebaseConsistencyError(
        "No Firebase service account key was found. "
        "Provide one with SMART_SHUTTLE_FIREBASE_SERVICE_ACCOUNT or "
        "backend/database/serviceAccountKey.local.json. "
        f"Checked: {checked}"
    )


def load_service_account_payload() -> tuple[Path, dict[str, Any]]:
    path = resolve_service_account_path()
    payload = _load_json_file(path)
    private_key = payload.get("private_key")
    if isinstance(private_key, str) and "\\n" in private_key:
        payload["private_key"] = private_key.replace("\\n", "\n")
    return path, payload


def parse_frontend_firebase_options() -> dict[str, dict[str, str]]:
    try:
        source = firebase_options_path().read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise FirebaseConsistencyError(
            f"Missing Flutter Firebase options file: {firebase_options_path()}"
        ) from exc

    platforms: dict[str, dict[str, str]] = {}
    for match in _DART_OPTION_BLOCK.finditer(source):
        fields: dict[str, str] = {}
        for dart_field, value in _DART_OPTION_FIELD.findall(match.group("body")):
            mapped = _DART_FIELD_MAP.get(dart_field)
            if mapped is not None:
                fields[mapped] = value
        platforms[match.group("platform")] = fields

    if not platforms:
        raise FirebaseConsistencyError(
            f"Unable to parse FirebaseOptions blocks from {firebase_options_path()}"
        )
    return platforms


def parse_android_google_services() -> dict[str, str]:
    payload = _load_json_file(google_services_path())
    project_info = dict(payload.get("project_info") or {})
    clients = list(payload.get("client") or [])
    client = dict(clients[0] or {}) if clients else {}
    client_info = dict(client.get("client_info") or {})
    android_info = dict(client_info.get("android_client_info") or {})
    api_keys = list(client.get("api_key") or [])
    api_key_payload = dict(api_keys[0] or {}) if api_keys else {}

    return {
        "project_id": str(project_info.get("project_id") or ""),
        "project_number": str(project_info.get("project_number") or ""),
        "storage_bucket": str(project_info.get("storage_bucket") or ""),
        "app_id": str(client_info.get("mobilesdk_app_id") or ""),
        "api_key": str(api_key_payload.get("current_key") or ""),
        "package_name": str(android_info.get("package_name") or ""),
    }


def _push_mismatch(
    mismatches: list[str],
    *,
    source: str,
    field: str,
    expected: Any,
    actual: Any,
) -> None:
    if expected == actual:
        return
    mismatches.append(
        f"{source} {field}: expected '{expected}' but found '{actual}'."
    )


def build_firebase_consistency_report() -> dict[str, Any]:
    manifest = load_manifest()
    expected_project_id = str(manifest.get("project_id") or "").strip()
    expected_project_number = str(manifest.get("project_number") or "").strip()
    platforms = {
        key: dict(value or {})
        for key, value in dict(manifest.get("platforms") or {}).items()
    }
    service_account_path, service_account_payload = load_service_account_payload()
    service_account_source = describe_service_account_source(service_account_path)
    frontend_options = parse_frontend_firebase_options()
    android_google_services = parse_android_google_services()

    client_email = str(service_account_payload.get("client_email") or "")
    client_email_domain = ""
    if "@" in client_email and ".iam.gserviceaccount.com" in client_email:
        client_email_domain = client_email.split("@", 1)[1].split(
            ".iam.gserviceaccount.com",
            1,
        )[0]

    mismatches: list[str] = []
    warnings: list[str] = []

    unexpected_artifacts: list[Path] = []
    android_root = google_services_path().parent.parent
    canonical_google_services = google_services_path().resolve()
    if android_root.exists():
        for candidate in sorted(android_root.rglob("google-services*.json")):
            if candidate.resolve() == canonical_google_services:
                continue
            unexpected_artifacts.append(candidate.resolve())

    unsupported_service_account = backend_database_dir() / "serviceAccountKey.json"
    if unsupported_service_account.exists():
        unexpected_artifacts.append(unsupported_service_account.resolve())

    if not expected_project_id:
        mismatches.append(
            f"Manifest {firebase_manifest_path()} is missing 'project_id'."
        )

    service_account_project_id = str(service_account_payload.get("project_id") or "")
    _push_mismatch(
        mismatches,
        source="Backend service account",
        field="Project ID",
        expected=expected_project_id,
        actual=service_account_project_id,
    )
    if client_email_domain:
        _push_mismatch(
            mismatches,
            source="Backend service account",
            field="Domain",
            expected=expected_project_id,
            actual=client_email_domain,
        )

    for platform_name, expected_platform in platforms.items():
        actual_platform = frontend_options.get(platform_name)
        if actual_platform is None:
            mismatches.append(
                f"Flutter firebase_options.dart is missing the '{platform_name}' platform block."
            )
            continue

        _push_mismatch(
            mismatches,
            source=f"Flutter firebase_options.dart [{platform_name}]",
            field="Project ID",
            expected=expected_project_id,
            actual=actual_platform.get("project_id", ""),
        )
        for field in (
            "api_key",
            "app_id",
            "messaging_sender_id",
            "auth_domain",
            "storage_bucket",
        ):
            if field not in expected_platform:
                continue
            _push_mismatch(
                mismatches,
                source=f"Flutter firebase_options.dart [{platform_name}]",
                field=_LABELS.get(field, field),
                expected=str(expected_platform.get(field) or ""),
                actual=str(actual_platform.get(field) or ""),
            )

    android_manifest = dict(platforms.get("android") or {})
    _push_mismatch(
        mismatches,
        source="Android google-services.json",
        field="Project ID",
        expected=expected_project_id,
        actual=android_google_services.get("project_id", ""),
    )
    if expected_project_number:
        _push_mismatch(
            mismatches,
            source="Android google-services.json",
            field="Project Number",
            expected=expected_project_number,
            actual=android_google_services.get("project_number", ""),
        )
    if "storage_bucket" in android_manifest:
        _push_mismatch(
            mismatches,
            source="Android google-services.json",
            field="Storage Bucket",
            expected=str(android_manifest.get("storage_bucket") or ""),
            actual=android_google_services.get("storage_bucket", ""),
        )
    if "app_id" in android_manifest:
        _push_mismatch(
            mismatches,
            source="Android google-services.json",
            field="App ID",
            expected=str(android_manifest.get("app_id") or ""),
            actual=android_google_services.get("app_id", ""),
        )
    if "api_key" in android_manifest:
        _push_mismatch(
            mismatches,
            source="Android google-services.json",
            field="API Key",
            expected=str(android_manifest.get("api_key") or ""),
            actual=android_google_services.get("api_key", ""),
        )

    expected_package_name = str(manifest.get("android_package_name") or "")
    if expected_package_name:
        _push_mismatch(
            mismatches,
            source="Android google-services.json",
            field="Android Package Name",
            expected=expected_package_name,
            actual=android_google_services.get("package_name", ""),
        )

    for artifact in unexpected_artifacts:
        warnings.append(
            "Unexpected Firebase config artifact detected: "
            f"{artifact}. Keep only the canonical tracked files and local "
            "serviceAccountKey.local.json to avoid drift."
        )

    return {
        "expected_project_id": expected_project_id,
        "expected_project_number": expected_project_number,
        "manifest_path": str(firebase_manifest_path()),
        "firebase_options_path": str(firebase_options_path()),
        "google_services_path": str(google_services_path()),
        "service_account_path": str(service_account_path),
        "service_account_source": service_account_source,
        "service_account_project_id": service_account_project_id,
        "service_account_client_email_domain": client_email_domain,
        "frontend_platforms": frontend_options,
        "android_google_services": android_google_services,
        "unexpected_artifacts": [str(path) for path in unexpected_artifacts],
        "warnings": warnings,
        "mismatches": mismatches,
    }


def format_firebase_consistency_report(report: dict[str, Any]) -> str:
    lines = [
        f"Expected Firebase project: {report.get('expected_project_id') or '<missing>'}",
        f"Manifest: {report.get('manifest_path')}",
        f"Flutter firebase_options.dart: {report.get('firebase_options_path')}",
        f"Android google-services.json: {report.get('google_services_path')}",
        f"Backend service account: {report.get('service_account_path')}",
        f"Backend service account source: {report.get('service_account_source')}",
        f"Backend service-account project: {report.get('service_account_project_id') or '<missing>'}",
    ]

    warnings = list(report.get("warnings") or [])
    if warnings:
        lines.append("Warnings:")
        lines.extend(f"- {warning}" for warning in warnings)

    mismatches = list(report.get("mismatches") or [])
    if mismatches:
        lines.append("Mismatches:")
        lines.extend(f"- {mismatch}" for mismatch in mismatches)
    else:
        lines.append("Mismatches: none")

    return "\n".join(lines)


def assert_firebase_consistency() -> dict[str, Any]:
    report = build_firebase_consistency_report()
    if report["mismatches"]:
        raise FirebaseConsistencyError(format_firebase_consistency_report(report))
    return report

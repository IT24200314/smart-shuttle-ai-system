import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = PROJECT_ROOT / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from utils.firebase_project_config import (  # noqa: E402
    describe_service_account_source,
    load_service_account_payload,
)


try:
    key_path, payload = load_service_account_payload()
    print(f"Resolved key path: {key_path}")
    print(f"Resolved key source: {describe_service_account_source(key_path)}")
    print(f"Project ID: {payload.get('project_id')}")
    print(f"Client Email: {payload.get('client_email')}")
    print(f"Private Key ID: {payload.get('private_key_id')}")
except Exception as e:
    print(f"Error: {e}")

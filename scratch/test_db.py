import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = PROJECT_ROOT / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from utils.firebase_project_config import (  # noqa: E402
    assert_firebase_consistency,
    load_service_account_payload,
)


try:
    report = assert_firebase_consistency()
    key_path, cert_dict = load_service_account_payload()
    print(f"Using Firebase project: {report['expected_project_id']}")
    print(f"Using service account: {key_path}")

    cred = credentials.Certificate(cert_dict)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)

    db = firestore.client()
    print("Attempting to read 'users' collection...")
    db.collection("users").limit(1).get(timeout=5)
    print("Success! Connection verified.")

except Exception as e:
    print(f"ERROR: {type(e).__name__}: {e}")
    import traceback

    traceback.print_exc()

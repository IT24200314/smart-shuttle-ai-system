import firebase_admin
from firebase_admin import credentials, firestore
import logging

from utils.firebase_project_config import (
    FirebaseConsistencyError,
    assert_firebase_consistency,
    load_service_account_payload,
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

_LAST_CONSISTENCY_REPORT = None

def initialize_firebase():
    """Initializes Firebase Admin SDK and returns a Firestore client."""
    global _LAST_CONSISTENCY_REPORT
    try:
        _LAST_CONSISTENCY_REPORT = assert_firebase_consistency()
        key_path, cert_dict = load_service_account_payload()
        if not firebase_admin._apps:
            logger.info("Initializing Firebase Admin SDK...")
            logger.info("Using Firebase service account file: %s", key_path)
            cred = credentials.Certificate(cert_dict)
            firebase_admin.initialize_app(cred)
            logger.info(
                "Firebase Admin SDK initialized successfully for project %s.",
                cert_dict.get("project_id"),
            )
        return firestore.client()
    except FirebaseConsistencyError as exc:
        logger.error("Firebase configuration consistency check failed.\n%s", exc)
        return None
    except Exception as e:
        logger.error(f"Error initializing Firebase: {e}", exc_info=True)
        return None


def require_firebase_runtime_ready():
    """Fails fast when Firebase config is inconsistent or initialization failed."""
    global _LAST_CONSISTENCY_REPORT
    _LAST_CONSISTENCY_REPORT = assert_firebase_consistency()
    if db is None:
        raise FirebaseConsistencyError(
            "Firebase Admin SDK could not be initialized. "
            "Fix the backend service account so it matches the canonical Firebase manifest."
        )
    return _LAST_CONSISTENCY_REPORT

def check_firestore_connection(db):
    """Verifies that the Firestore client can actually communicate with the server."""
    if db is None:
        return False
    try:
        # Attempt a lightweight operation to verify connectivity with a 5-second timeout
        logger.info("Verifying Firestore connectivity...")
        # Use a limit(1) query on a common collection or metadata
        db.collection("users").limit(1).get(timeout=5)
        logger.info("Firestore connectivity verified.")
        return True
    except Exception as e:
        if "invalid_grant" in str(e).lower() or "jwt" in str(e).lower():
            logger.error("AUTHENTICATION ERROR: Firestore rejected the JWT signature. "
                         "This usually means the configured Firebase service account key is invalid, "
                         "mangled, or belongs to a different project.")
        else:
            logger.error(f"Firestore connectivity check failed: {e}")
        return False

# Initialize the global db instance
db = initialize_firebase()

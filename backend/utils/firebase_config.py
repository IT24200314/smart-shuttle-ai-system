import firebase_admin
from firebase_admin import credentials, firestore
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def initialize_firebase():
    """Initializes Firebase Admin SDK and returns a Firestore client."""
    try:
        if not firebase_admin._apps:
            logger.info("Initializing Firebase Admin SDK...")
            key_path = os.path.join(os.path.dirname(__file__), '../database/serviceAccountKey.json')
            if not os.path.exists(key_path):
                logger.error(f"Firebase service account key not found at: {key_path}")
                return None
            
            # Load and sanitize the key to prevent "Invalid JWT Signature" errors
            import json
            with open(key_path, 'r') as f:
                cert_dict = json.load(f)
            
            if 'private_key' in cert_dict:
                # Replace literal \n with actual newlines if they were double-escaped
                cert_dict['private_key'] = cert_dict['private_key'].replace('\\n', '\n')
            
            cred = credentials.Certificate(cert_dict)
            firebase_admin.initialize_app(cred)
            logger.info(
                "Firebase Admin SDK initialized successfully for project %s.",
                cert_dict.get("project_id"),
            )
        return firestore.client()
    except Exception as e:
        logger.error(f"Error initializing Firebase: {e}", exc_info=True)
        return None

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
                         "This usually means the private_key in serviceAccountKey.json is invalid, "
                         "mangled, or belongs to a different project.")
        else:
            logger.error(f"Firestore connectivity check failed: {e}")
        return False

# Initialize the global db instance
db = initialize_firebase()

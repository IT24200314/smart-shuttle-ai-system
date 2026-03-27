import firebase_admin
from firebase_admin import credentials, firestore
import os

def initialize_firebase():
    # If already initialized, return the db client
    try:
        if not firebase_admin._apps:
            # We assume the key is in the root of backend, or we can copy it here.
            # Let's point to the one in ai_models for now to avoid duplication.
            key_path = os.path.join(os.path.dirname(__file__), '../database/serviceAccountKey.json')
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f"Error initializing Firebase: {e}")
        return None

db = initialize_firebase()

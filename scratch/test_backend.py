import os
import sys
import time

# Add backend to sys.path
backend_path = r'c:\suttle project\smart-shuttle-ai-system\backend'
sys.path.append(backend_path)

print("Script started...")

try:
    from utils.firebase_config import (
        check_firestore_connection,
        db,
        require_firebase_runtime_ready,
    )
    print("Imports success.")
except Exception as e:
    print(f"Import failed: {e}")
    sys.exit(1)

def test_firebase():
    try:
        report = require_firebase_runtime_ready()
        print(f"Firebase project locked to: {report['expected_project_id']}")
        print(f"Service account source: {report['service_account_source']}")
        print(f"Service account path: {report['service_account_path']}")
        print("Firebase initialized. Attempting a real read (fetching one user)...")

        start = time.time()
        ok = check_firestore_connection(db)
        if not ok:
            print("FAILED: Firestore connectivity check returned False.")
            return

        docs = list(db.collection("users").limit(1).stream())
        print(f"Read successful. Fetched {len(docs)} documents.")
        if docs:
            print(f"First doc ID: {docs[0].id}")

        print(f"Total time taken: {time.time() - start:.2f} seconds.")
    except Exception as e:
        print(f"FAILED with error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_firebase()

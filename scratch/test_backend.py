import os
import sys
import time

# Add backend to sys.path
backend_path = r'c:\suttle project\smart-shuttle-ai-system\backend'
sys.path.append(backend_path)

print("Script started...")

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    print("Imports success.")
except Exception as e:
    print(f"Import failed: {e}")
    sys.exit(1)

def test_firebase():
    key_path = os.path.join(backend_path, 'database', 'serviceAccountKey.json')
    print(f"Checking key path: {key_path}")
    if not os.path.exists(key_path):
        print("FAILED: serviceAccountKey.json not found.")
        return

    print("Initializing Firebase...")
    try:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase initialized. Attempting a real read (fetching one user)...")
        
        start = time.time()
        # Fetching a document to force network activity
        doc_ref = db.collection("users").limit(1)
        docs = list(doc_ref.stream())
        
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

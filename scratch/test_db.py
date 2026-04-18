
import json
import firebase_admin
from firebase_admin import credentials, firestore
import os

key_path = r'c:\suttle project\smart-shuttle-ai-system\backend\database\serviceAccountKey.json'

try:
    with open(key_path, 'r') as f:
        data = json.load(f)
        print(f"Project ID: {data.get('project_id')}")
        pk = data.get('private_key', '')
        print(f"Private Key Length: {len(pk)}")
        print(f"Private Key Repr (first 100): {repr(pk[:100])}")
        print(f"Private Key Ends with: {pk[-30:]}")
        
    cred = credentials.Certificate(key_path)
    # Don't initialize if already done
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    print("Attempting to read 'users' collection...")
    doc = db.collection('users').limit(1).get(timeout=5)
    print("Success! Connection verified.")

except Exception as e:
    print(f"ERROR: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()

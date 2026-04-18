import json
import os

key_path = r'c:\suttle project\smart-shuttle-ai-system\backend\database\serviceAccountKey.json'

try:
    with open(key_path, 'r') as f:
        data = json.load(f)
        print(f"Project ID: {data.get('project_id')}")
        print(f"Client Email: {data.get('client_email')}")
        pk = data.get('private_key', '')
        print(f"Private Key starts with: {pk[:50]}...")
        print(f"Private Key ends with: ...{pk[-50:]}")
        if '\n' in pk:
            print("Found literal newlines in private key string.")
        if '\\n' in pk:
            print("Found escaped \\n in private key string.")
except Exception as e:
    print(f"Error: {e}")

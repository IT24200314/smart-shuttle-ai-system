import requests
import time

BASE_URL = "http://127.0.0.1:8000"

def verify_backend():
    print(f"Checking backend at {BASE_URL}...")
    
    # Wait a bit for server to start if we were starting it
    # time.sleep(2)
    
    try:
        # Check basic health
        resp = requests.get(f"{BASE_URL}/health")
        print(f"Health check: {resp.status_code} - {resp.json()}")
        
        # Check DB health
        resp = requests.get(f"{BASE_URL}/health/db")
        print(f"DB Health check: {resp.status_code} - {resp.json()}")
        
    except Exception as e:
        print(f"Verification failed: {e}")

if __name__ == "__main__":
    verify_backend()

import requests

BASE_URL = "http://localhost:8000"

def test_auth():
    print("Testing Registration...")
    res = requests.post(f"{BASE_URL}/auth/register", json={
        "name": "Test User",
        "email": "testauthproof_final@test.com",
        "role": "student",
        "password": "pass123"
    })
    print("Register Status:", res.status_code)
    print("Register Body:", res.text)
    
    print("\nTesting Duplicate Email...")
    res2 = requests.post(f"{BASE_URL}/auth/register", json={
        "name": "Test User",
        "email": "testauthproof_final@test.com",
        "role": "student",
        "password": "pass123"
    })
    print("Dup Register Status:", res2.status_code)
    print("Dup Register Body:", res2.text)

    print("\nTesting Wrong Password...")
    res3 = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "testauthproof_final@test.com",
        "password": "wrongpassword"
    })
    print("Wrong Pw Status:", res3.status_code)
    print("Wrong Pw Body:", res3.text)

    print("\nTesting Login Success...")
    res4 = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "testauthproof_final@test.com",
        "password": "pass123"
    })
    print("Login Status:", res4.status_code)
    print("Login Body:", res4.text)

if __name__ == "__main__":
    test_auth()

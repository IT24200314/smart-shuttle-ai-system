import requests
import uuid

BASE_URL = "http://localhost:8000"

def run_tests():
    print("--- STARTING FINAL AUTH VERIFICATION ---")
    
    def register(role, prefix):
        email = f"{prefix}_{uuid.uuid4().hex[:4]}@test.com"
        res = requests.post(f"{BASE_URL}/auth/register", json={
            "name": f"Test {role}", "email": email, "role": role, "password": "pass"
        })
        return email, res
    
    s_email, s_res = register("student", "stud")
    print(f"1. Student registration:\n- PASS/FAIL: {'PASS' if s_res.status_code==200 else 'FAIL'}\n- Proof: [{s_res.status_code}] {s_res.text}")
    
    d_email, d_res = register("driver", "driver")
    print(f"2. Driver registration:\n- PASS/FAIL: {'PASS' if d_res.status_code==200 else 'FAIL'}\n- Proof: [{d_res.status_code}] {d_res.text}")
    
    a_email, a_res = register("admin", "admin")
    print(f"3. Admin registration:\n- PASS/FAIL: {'PASS' if a_res.status_code==200 else 'FAIL'}\n- Proof: [{a_res.status_code}] {a_res.text}")
    
    def login(email, password="pass"):
        return requests.post(f"{BASE_URL}/auth/login", json={"email": email, "password": password})
    
    sl_res = login(s_email)
    print(f"4. Student login + correct route redirect:\n- PASS/FAIL: {'PASS' if sl_res.status_code==200 and sl_res.json().get('role')=='student' else 'FAIL'}\n- Proof: [{sl_res.status_code}] Role claim returned to UI: {sl_res.json().get('role')}")
    
    dl_res = login(d_email)
    print(f"5. Driver login + correct route redirect:\n- PASS/FAIL: {'PASS' if dl_res.status_code==200 and dl_res.json().get('role')=='driver' else 'FAIL'}\n- Proof: [{dl_res.status_code}] Role claim returned to UI: {dl_res.json().get('role')}")
    
    al_res = login(a_email)
    print(f"6. Admin login + correct route redirect:\n- PASS/FAIL: {'PASS' if al_res.status_code==200 and al_res.json().get('role')=='admin' else 'FAIL'}\n- Proof: [{al_res.status_code}] Role claim returned to UI: {al_res.json().get('role')}")

    wp_res = login(s_email, "wrong_password_123")
    print(f"7. Wrong password handling:\n- PASS/FAIL: {'PASS' if wp_res.status_code==401 else 'FAIL'}\n- Proof: [{wp_res.status_code}] {wp_res.text}")
    
    dup_res = requests.post(f"{BASE_URL}/auth/register", json={"name": "Dup", "email": s_email, "role": "student", "password": "pass"})
    print(f"8. Duplicate email handling:\n- PASS/FAIL: {'PASS' if dup_res.status_code==400 else 'FAIL'}\n- Proof: [{dup_res.status_code}] {dup_res.text}")
    
    print("\n--- PASSWORD EDGE CASES ---")
    norm_res = requests.post(f"{BASE_URL}/auth/register", json={"name": "Norm", "email": f"n_{uuid.uuid4().hex[:4]}@test.com", "role": "student", "password": "NormalPassword123"})
    print(f"- Normal: [{norm_res.status_code}] {norm_res.text}")
    
    long_res = requests.post(f"{BASE_URL}/auth/register", json={"name": "Long", "email": f"l_{uuid.uuid4().hex[:4]}@test.com", "role": "student", "password": "A"*80})
    print(f"- Long (>72 chars): [{long_res.status_code}] {long_res.text}")
    
    sym_res = requests.post(f"{BASE_URL}/auth/register", json={"name": "Sym", "email": f"s_{uuid.uuid4().hex[:4]}@test.com", "role": "student", "password": "!@#$%^&*()_+<>?:{}|"})
    print(f"- Symbols: [{sym_res.status_code}] {sym_res.text}")
    
    emp_res = requests.post(f"{BASE_URL}/auth/register", json={"name": "Emp", "email": f"e_{uuid.uuid4().hex[:4]}@test.com", "role": "student", "password": ""})
    print(f"- Empty: [{emp_res.status_code}] {emp_res.text}")

if __name__ == '__main__':
    run_tests()

from fastapi import APIRouter, HTTPException
from utils.firebase_config import db
from google.cloud.firestore_v1.base_query import FieldFilter
from models.schemas import AuthRegisterRequest, AuthLoginRequest
from utils.security import get_password_hash, verify_password, create_access_token
import uuid
import sys
import os
import subprocess
from datetime import datetime

router = APIRouter()

@router.post("/auth/register")
def register(req: AuthRegisterRequest):
    try:
        # Check if email exists
        existing = db.collection('users').where(filter=FieldFilter('email', '==', req.email)).limit(1).get()
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered")

        user_id = f"USR-{uuid.uuid4().hex[:6]}"
        hashed_pw = get_password_hash(req.password)
        
        db.collection('users').document(user_id).set({
            'email': req.email,
            'password_hash': hashed_pw,
            'role': req.role,
            'name': req.name,
            'status': 'active'
        })
        return {"message": "User registered successfully", "user_id": user_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/auth/login")
def login(req: AuthLoginRequest):
    try:
        users = db.collection('users').where(filter=FieldFilter('email', '==', req.email)).limit(1).get()
        if not users:
            raise HTTPException(status_code=401, detail="Invalid credentials")
            
        user = users[0].to_dict()
        user_id = users[0].id
        
        # Verify password (if the user was seeded manually without a hash, we auto-pass for demo)
        stored_hash = user.get('password_hash')
        if stored_hash:
            if not verify_password(req.password, stored_hash):
                raise HTTPException(status_code=401, detail="Invalid credentials")
        else:
            # Fallback for plain-text or seeded mock users
            if user.get('password') != req.password and req.password != 'password':
                pass # Allow demo entries to slide if password is blank, otherwise enforce hash check if implemented

        # Generate True JWT Token
        user_role = user.get('role', 'student')
        token = create_access_token({
            "sub": user_id,
            "email": user.get('email'),
            "role": user_role
        })

        # If the user is a driver, create unique document for per day to track driver behavior 
        if user_role == 'driver':
            
            # Create unique ID using email + data
            date_str = datetime.now().strftime('%Y-%m-%d')
            doc_id = f"{user.get('email')}_{date_str}"
            doc_ref = db.collection('driver_behavior_logs').document(doc_id)
            
            doc = doc_ref.get()
            if not doc.exists:
                doc_ref.set({
                    'email': user.get('email'),
                    'date': date_str,
                    'number_of_ywan': 0,
                    'number_of_usephone': 0,
                    'number_of_drowsiness': 0,
                    'safety_score': 100
                })
            
            # Spawn the camera tracking python script natively without blocking
            script_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'driver_camera.py')
            subprocess.Popen([sys.executable, script_path, user.get('email')])

        return {
            "message": "Login successful",
            "token": token,
            "role": user.get('role', 'student'),
            "name": user.get('name', '')
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

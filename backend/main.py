from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from routes import dashboard_routes, driver_routes, auth_routes, lost_found_routes, map_routes, admin_routes, user_routes, feedback_routes
from utils.firebase_config import db, check_firestore_connection

app = FastAPI(title="Smart Shuttle Operations API")

# Allow Flutter apps (running on emulator or web) to hit the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    # Verify database connection on startup
    if not check_firestore_connection(db):
        print("WARNING: Firestore connectivity check failed on startup. Some features may be unavailable.")

app.include_router(dashboard_routes.router)
app.include_router(driver_routes.router)
app.include_router(auth_routes.router)
app.include_router(lost_found_routes.router)
app.include_router(map_routes.router)
app.include_router(admin_routes.router)
app.include_router(user_routes.router)
app.include_router(feedback_routes.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Smart Shuttle Operations API"}

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "Smart Shuttle API"}

@app.get("/health/db")
def db_health_check():
    if check_firestore_connection(db):
        return {"status": "ok", "database": "Firestore connected"}
    else:
        raise HTTPException(status_code=503, detail="Firestore unreachable or hanging")

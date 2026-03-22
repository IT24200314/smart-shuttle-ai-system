from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import dashboard_routes, driver_routes, auth_routes, lost_found_routes, map_routes, admin_routes

app = FastAPI(title="Smart Shuttle Operations API")

# Allow Flutter apps (running on emulator or web) to hit the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(dashboard_routes.router)
app.include_router(driver_routes.router)
app.include_router(auth_routes.router)
app.include_router(lost_found_routes.router)
app.include_router(map_routes.router)
app.include_router(admin_routes.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Smart Shuttle Operations API"}

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "Smart Shuttle API"}

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import os
import datetime
import json
from pathlib import Path
from dotenv import load_dotenv
from fastapi.staticfiles import StaticFiles
from orchestrator import run_orchestration, get_booking, get_all_bookings, _jobs

# ─── In‑memory notification queues per provider (simple demo)
_notifications: dict[str, list[dict]] = {}  # provider_id → list of messages

# Helper to push a notification to a provider
def _push_notification(provider_id: str, message: str):
    if provider_id not in _notifications:
        _notifications[provider_id] = []
    _notifications[provider_id].append({
        "message": message,
        "timestamp": datetime.datetime.utcnow().isoformat()
    })

# Live provider location store (keyed by provider_id)
_provider_locations: dict = {}
_provider_profiles: dict = {}

load_dotenv()

app = FastAPI(
    title="KhidmatGar Antigravity Backend",
    description="5-Agent AI Service Orchestrator for Pakistan's Informal Economy",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("web", exist_ok=True)
app.mount("/web", StaticFiles(directory="web", html=True), name="web")



class RunRequest(BaseModel):
    inputs: dict
    stream: bool = False
    session_id: Optional[str] = None

class RateRequest(BaseModel):
    provider_id: str
    rating: float
    review: Optional[str] = None

# ─── Health Check ───────────────────────────────────────────
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "KhidmatGar Antigravity Backend",
        "version": "2.0.0",
        "agents": ["ZARA", "KHOJI", "MUKHTAR", "YAKEEN", "HIFAZAT"],
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "env": {
            "gemini_configured": bool(os.getenv("GEMINI_API_KEY")),
            "maps_configured": bool(os.getenv("GOOGLE_MAPS_API_KEY")),
        }
    }


# ─── Main Orchestration Endpoint ────────────────────────────
@app.post("/v1/workflows/khidmatgar-master/run")
async def run_workflow(request: RunRequest):
    user_message = request.inputs.get("user_message", "")
    if not user_message or not user_message.strip():
        raise HTTPException(status_code=400, detail="user_message is required and cannot be empty")

    session_id = request.session_id or request.inputs.get("session_id")
    platform = request.inputs.get("platform", "flutter")
    client_lat = request.inputs.get("client_lat")
    client_lng = request.inputs.get("client_lng")

    try:
        response = await run_orchestration(
            user_message=user_message.strip(),
            session_id=session_id,
            platform=platform,
            client_lat=client_lat,
            client_lng=client_lng
        )
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Orchestration error: {str(e)}")


# ─── Simple Chat Endpoint (easier for testing) ───────────────
@app.post("/chat")
async def chat(body: dict):
    message = body.get("message", "")
    session_id = body.get("session_id")
    if not message:
        raise HTTPException(status_code=400, detail="message is required")
    response = await run_orchestration(message, session_id=session_id)
    return response

# ─── Provider & Client Flow Endpoints ─────────────────────────

@app.get("/provider/jobs")
async def list_provider_jobs():
    """Provider Dashboard: Fetch all PENDING or ACTIVE jobs"""
    jobs = []
    for jid, job in _jobs.items():
        if job.get("status") in ["PENDING", "CONFIRMED", "ARRIVED"]:
            jobs.append(job)
    # Sort newest first
    jobs.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return {"jobs": jobs}

@app.post("/provider/jobs/{job_id}/bid")
async def submit_bid(job_id: str, body: dict):
    """Provider Dashboard: Submit a bid for a PENDING job"""
    job = _jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
        
    price = body.get("price")
    provider_id = body.get("provider_id", "PRV-ISB-001")
    provider_name = body.get("provider_name", "Provider")
    eta_minutes = body.get("eta_minutes", 15)
    
    if not price:
        raise HTTPException(status_code=400, detail="price is required")
        
    job["status"] = "BID_RECEIVED"
    job["bids"] = job.get("bids", [])
    job["bids"].append({
        "provider_id": provider_id,
        "provider_name": provider_name,
        "price": price,
        "eta_minutes": eta_minutes,
        "timestamp": datetime.datetime.utcnow().isoformat()
    })
    
    return {"success": True, "job": job}

@app.post("/provider/jobs/{job_id}/arrive")
async def mark_job_arrived(job_id: str):
    """Provider Dashboard: Mark job as ARRIVED"""
    job = _jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    job["status"] = "ARRIVED"
    return {"success": True, "job": job}

@app.get("/provider/notifications/{provider_id}")
async def get_provider_notifications(provider_id: str):
    """Fetch notifications for a provider"""
    notifications = _notifications.get(provider_id, [])
    return {"notifications": notifications[::-1]}

@app.get("/client/sessions/{session_id}/updates")
async def check_client_updates(session_id: str):
    """Client Chat: Poll for incoming bids or status changes"""
    updates = []
    for jid, job in _jobs.items():
        if job.get("session_id") == session_id:
            if job.get("status") == "BID_RECEIVED":
                # Get latest bid
                latest_bid = job["bids"][-1]
                updates.append({
                    "type": "BID",
                    "job_id": jid,
                    "message": f"SYSTEM_INCOMING_BID:{latest_bid['provider_name']}:{latest_bid['price']}:{latest_bid['eta_minutes']}:{jid}"
                })
            elif job.get("status") == "ARRIVED" and not job.get("arrival_notified"):
                job["arrival_notified"] = True
                updates.append({
                    "type": "ARRIVED",
                    "job_id": jid,
                    "message": "SYSTEM_PROVIDER_ARRIVED"
                })
    return {"updates": updates}


# ─── Bookings Endpoints ──────────────────────────────────────
@app.get("/bookings")
async def list_bookings():
    bookings = get_all_bookings()
    return {
        "total": len(bookings),
        "bookings": bookings
    }


@app.get("/bookings/{booking_id}")
async def get_booking_detail(booking_id: str):
    booking = get_booking(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail=f"Booking {booking_id} not found")
    return booking


@app.get("/bookings/{booking_id}/status")
async def get_booking_status(booking_id: str):
    booking = get_booking(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    try:
        created_dt = datetime.datetime.fromisoformat(booking.get("created_at", datetime.datetime.utcnow().isoformat()).replace("Z", "+00:00"))
        elapsed_minutes = (datetime.datetime.now(datetime.timezone.utc) - created_dt).total_seconds() / 60
        
        if elapsed_minutes < 1:
            status = "CONFIRMED"
        elif elapsed_minutes < 5:
            status = "EN_ROUTE"
        elif elapsed_minutes < 15:
            status = "ARRIVED"
        elif elapsed_minutes < 60:
            status = "IN_PROGRESS"
        else:
            status = "COMPLETED"
            
        return {
            "booking_id": booking_id,
            "status": status,
            "provider_id": booking["provider_id"],
            "elapsed_minutes": int(elapsed_minutes)
        }
    except Exception as e:
        return {"booking_id": booking_id, "status": "CONFIRMED", "error": str(e)}


@app.post("/bookings/{booking_id}/cancel")
async def cancel_booking(booking_id: str):
    """Cancel a booking and notify the provider.
    
    Sets booking status to "CANCELLED", records cancellation timestamp,
    and pushes a notification to the provider's in‑memory queue.
    """
    booking = get_booking(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail=f"Booking {booking_id} not found")
    # Update status
    booking["status"] = "CANCELLED"
    booking["cancelled_at"] = datetime.datetime.utcnow().isoformat()
    # Notify provider if provider_id present
    provider_id = booking.get("provider_id")
    if provider_id:
        _push_notification(provider_id, f"Booking {booking_id} has been cancelled by the client.")
    return {"success": True, "booking": booking}

@app.post("/rate")
async def rate_provider(request: RateRequest):
    db_path = Path(__file__).parent / "data" / "providers_db.json"
    try:
        with open(db_path, "r", encoding="utf-8") as f:
            db = json.load(f)
        
        updated = False
        for p in db.get("providers", []):
            if p["provider_id"] == request.provider_id:
                old_rating = p.get("rating", 5.0)
                old_count = p.get("review_count", 1)
                new_count = old_count + 1
                new_rating = ((old_rating * old_count) + request.rating) / new_count
                p["rating"] = round(new_rating, 1)
                p["review_count"] = new_count
                updated = True
                break
                
        if updated:
            with open(db_path, "w", encoding="utf-8") as f:
                json.dump(db, f, indent=2)
            _push_notification(request.provider_id, f"New rating received: {request.rating} stars.")
            return {"status": "success", "message": "Rating updated successfully"}
        else:
            raise HTTPException(status_code=404, detail="Provider not found")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ─── Agent Info Endpoint ─────────────────────────────────────
@app.get("/agents")
async def list_agents():
    return {
        "agents": [
            {
                "id": "ZARA",
                "role": "Intent Parser",
                "model": "gemini-1.5-flash",
                "capabilities": ["multilingual NLP", "Urdu/Roman Urdu/English", "urgency scoring", "location extraction"]
            },
            {
                "id": "KHOJI",
                "role": "Provider Discovery",
                "tools": ["google_maps_places", "internal_provider_db", "openweathermap"],
                "capabilities": ["real provider search", "5-factor scoring", "radius expansion", "weather context"]
            },
            {
                "id": "MUKHTAR",
                "role": "Autonomous Booking",
                "capabilities": ["auto-booking", "slot assignment", "multilingual confirmation", "firebase sync"]
            },
            {
                "id": "YAKEEN",
                "role": "Follow-up & Scheduling",
                "capabilities": ["reminder scheduling", "no-show guard", "rating collection", "completion check"]
            },
            {
                "id": "HIFAZAT",
                "role": "Guardian & Error Recovery",
                "capabilities": ["api fallback", "radius expansion", "ambiguity resolution", "emergency routing", "duplicate detection"]
            }
        ]
    }


# ─── Provider Registration (from Flutter ProviderRegistrationScreen) ──────────
@app.post("/provider/register")
async def register_provider(body: dict):
    """
    Receive and persist provider profile from Flutter registration screen.
    Called when provider completes ProviderRegistrationScreen.
    """
    provider_id = body.get("provider_id")
    if not provider_id:
        # Generate one from name
        name = body.get("provider_name", "provider").lower().replace(" ", "_")[:8]
        provider_id = f"PRV-{name.upper()}-{int(datetime.datetime.utcnow().timestamp()) % 10000}"
    
    # Extract location and services from body
    lat = body.get("lat")
    lng = body.get("lng")
    services = body.get("services", [])
    
    provider_doc = {
        "provider_id": provider_id,
        "name": body.get("provider_name", "Unknown"),
        "phone": body.get("phone", ""),
        "company": body.get("company_name", ""),
        "service_categories": services,
        "coordinates": {"lat": lat, "lng": lng} if lat and lng else None,
        "areas_served": [body.get("manual_area", "")] if body.get("manual_area") else [],
        "city": "Islamabad", # Default to Islamabad, or extract from area later
        "rating": 5.0,
        "review_count": 0,
        "response_rate": 1.0,
        "verification": {"level": "KHIDMATGAR_VERIFIED", "status": "VERIFIED"},
        "availability": {
            "available_today": True,
            "accepts_emergency": True,
            "next_slot": "Today ASAP",
        },
        "registered_at": datetime.datetime.utcnow().isoformat(),
        "_is_live_registered": True # Flag to boost in KHOJI
    }

    _provider_profiles[provider_id] = provider_doc
    
    # Persist to providers_db.json so KHOJI can see it
    db_path = Path(__file__).parent / "data" / "providers_db.json"
    try:
        with open(db_path, "r", encoding="utf-8") as f:
            db = json.load(f)
            
        # Check if exists, update or append
        existing = next((p for p in db.get("providers", []) if p["provider_id"] == provider_id), None)
        if existing:
            existing.update(provider_doc)
        else:
            db.setdefault("providers", []).append(provider_doc)
            
        with open(db_path, "w", encoding="utf-8") as f:
            json.dump(db, f, indent=2)
    except Exception as e:
        print(f"Failed to persist provider to DB: {e}")

    return {"success": True, "provider_id": provider_id}


# ─── Provider Live Location Push ──────────────────────────────────────────────
@app.post("/provider/location")
async def update_provider_location(body: dict):
    """
    Provider app pushes GPS coordinates every 8 seconds.
    Called by ProviderDashboard._pushLocationToBackend()
    """
    provider_id = body.get("provider_id")
    lat = body.get("lat")
    lng = body.get("lng")
    
    if not provider_id or lat is None or lng is None:
        raise HTTPException(status_code=400, detail="provider_id, lat, lng required")
    
    _provider_locations[provider_id] = {
        "lat": lat,
        "lng": lng,
        "timestamp": body.get("timestamp", datetime.datetime.utcnow().isoformat()),
    }
    
    # Update active jobs with fresh provider coordinates
    for job in _jobs.values():
        if job.get("provider_id") == provider_id:
            if "location" not in job:
                job["location"] = {}
            job["location"]["provider_live_coordinates"] = {"lat": lat, "lng": lng}
    
    return {"success": True}


# ─── Provider Live Location Fetch ─────────────────────────────────────────────
@app.get("/provider/location/{provider_id}")
async def get_provider_location(provider_id: str):
    """
    Client map screen polls this every 4 seconds.
    Called by MapViewScreen._pollProviderLocation()
    """
    loc = _provider_locations.get(provider_id)
    if not loc:
        raise HTTPException(status_code=404, detail="No location data for this provider")
    return loc


# ─── Calculate Distance & ETA ─────────────────────────────────────────────────
@app.get("/distance")
async def calculate_distance(
    lat1: float,
    lng1: float,
    lat2: float,
    lng2: float,
):
    """
    Haversine distance + ETA between two GPS points.
    Used by both client and provider sides.
    """
    import math
    R = 6371.0
    lat1_r, lng1_r, lat2_r, lng2_r = map(math.radians, [lat1, lng1, lat2, lng2])
    dlat = lat2_r - lat1_r
    dlng = lng2_r - lng1_r
    a = math.sin(dlat/2)**2 + math.cos(lat1_r)*math.cos(lat2_r)*math.sin(dlng/2)**2
    dist_km = R * 2 * math.asin(math.sqrt(a))
    eta_minutes = max(5, int((dist_km / 30) * 60) + 5)  # 30 km/h + 5 min buffer
    
    return {
        "distance_km": round(dist_km, 2),
        "eta_minutes": eta_minutes,
        "speed_assumed_kmh": 30,
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)

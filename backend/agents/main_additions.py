"""
main.py — ADDITIONS for live provider location tracking
Add these endpoints to the existing main.py FastAPI app.
Also includes the /provider/register endpoint for persisting provider profiles.

INSTRUCTIONS:
1. Add `_provider_locations: dict = {}` near the top (after _jobs / _sessions import from orchestrator)
2. Add `_provider_profiles: dict = {}` similarly
3. Paste these endpoints into the FastAPI app
4. In run_mukhtar_booking() in orchestrator.py, add client_coordinates to booking["location"]:
      booking["location"]["client_coordinates"] = {
          "lat": client_lat, "lng": client_lng
      }
   Pass client_lat/client_lng through the chain: run_orchestration → run_mukhtar_booking
"""

# ── ADD to orchestrator.py imports / globals ──────────────────────────────────
"""
_provider_locations: dict = {}   # provider_id -> {lat, lng, timestamp}
_provider_profiles: dict = {}    # provider_id -> full profile dict
"""

# ── ADD these routes to main.py ───────────────────────────────────────────────

PROVIDER_LOCATION_ROUTES = '''
from fastapi import FastAPI, HTTPException
import datetime

# In-memory location store (use Redis in production)
_provider_locations: dict = {}
_provider_profiles: dict = {}


# ─── Provider Registration ────────────────────────────────────────────────────

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
    
    _provider_profiles[provider_id] = {
        **body,
        "provider_id": provider_id,
        "registered_at": datetime.datetime.utcnow().isoformat(),
        "rating": 5.0,
        "review_count": 0,
        "verification": {"level": "KHIDMATGAR_VERIFIED"},
        "availability": {
            "available_today": True,
            "accepts_emergency": True,
            "next_slot": "Today ASAP",
        },
    }
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
'''


# ─── Orchestrator patch: pass client_lat/lng to mukhtar ──────────────────────
ORCHESTRATOR_PATCH = '''
# In orchestrator.py → run_orchestration(), find the mukhtar call:

    mukhtar_result = run_mukhtar_booking(top_provider, intent, session_id)

# Replace with:

    mukhtar_result = run_mukhtar_booking(
        top_provider, intent, session_id,
        client_lat=client_lat, client_lng=client_lng
    )

# In mukhtar_agent.py → run_mukhtar_booking(), add client_lat/client_lng params:

def run_mukhtar_booking(
    top_provider: dict,
    intent: dict,
    session_id: str,
    client_lat: float = None,
    client_lng: float = None,
) -> dict:
    ...
    booking = {
        ...
        "location": {
            "area": area,
            "city": city,
            "provider_coordinates": top_provider.get("coordinates"),
            # ← ADD THIS:
            "client_coordinates": {
                "lat": client_lat,
                "lng": client_lng,
            } if client_lat and client_lng else None,
        },
        ...
    }
'''

# Print patches when this file is imported as a reference
if __name__ == "__main__":
    print("=== Provider Location Routes ===")
    print(PROVIDER_LOCATION_ROUTES)
    print("\n=== Orchestrator Patch ===")
    print(ORCHESTRATOR_PATCH)

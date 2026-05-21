#!/usr/bin/env python3
"""
apply_patches.py — Run this ONCE from the backend/ directory to apply all fixes.
Usage:  cd backend && python apply_patches.py
"""
import re
import shutil
from pathlib import Path

BACKEND = Path(__file__).parent

def patch_file(path: Path, old: str, new: str, label: str):
    content = path.read_text(encoding="utf-8")
    if old not in content:
        print(f"  ⚠️  [{label}] pattern not found — may already be patched or file differs")
        return
    patched = content.replace(old, new, 1)
    path.write_text(patched, encoding="utf-8")
    print(f"  ✅  [{label}] applied")

# ── 1. zara_agent.py — remove Islamabad default ──────────────────────────────
print("\n[1/4] Patching zara_agent.py — remove Islamabad default city...")
zara_path = BACKEND / "agents" / "zara_agent.py"
if zara_path.exists():
    # Backup
    shutil.copy(zara_path, zara_path.with_suffix(".py.bak"))
    patch_file(
        zara_path,
        '    return "Islamabad"  # Default to capital',
        '    return ""  # FIXED: No default city — let clarification_needed trigger',
        "zara: remove Islamabad default",
    )
else:
    print("  ⚠️  zara_agent.py not found — copy fixed version from khadmatgar_fixed/backend/")

# ── 2. orchestrator.py — pass client_lat/lng to mukhtar ──────────────────────
print("\n[2/4] Patching orchestrator.py — pass GPS to mukhtar...")
orch_path = BACKEND / "orchestrator.py"
if orch_path.exists():
    shutil.copy(orch_path, orch_path.with_suffix(".py.bak"))
    patch_file(
        orch_path,
        "        mukhtar_result = run_mukhtar_booking(top_provider, zara_result, session_id)",
        "        mukhtar_result = run_mukhtar_booking(top_provider, zara_result, session_id, client_lat=client_lat, client_lng=client_lng)",
        "orchestrator: pass GPS to mukhtar",
    )
else:
    print("  ⚠️  orchestrator.py not found")

# ── 3. mukhtar_agent.py — accept and store client_coordinates ────────────────
print("\n[3/4] Patching mukhtar_agent.py — store client_coordinates in booking...")
mukhtar_path = BACKEND / "agents" / "mukhtar_agent.py"
if mukhtar_path.exists():
    shutil.copy(mukhtar_path, mukhtar_path.with_suffix(".py.bak"))
    # Patch function signature
    patch_file(
        mukhtar_path,
        "def run_mukhtar_booking(top_provider: dict, intent: dict, session_id: str) -> dict:",
        "def run_mukhtar_booking(top_provider: dict, intent: dict, session_id: str, client_lat: float = None, client_lng: float = None) -> dict:",
        "mukhtar: add client_lat/lng params",
    )
    # Patch booking location dict
    patch_file(
        mukhtar_path,
        '''"location": {
            "area": area,
            "city": city,
            "provider_coordinates": top_provider.get("coordinates")
        },''',
        '''"location": {
            "area": area,
            "city": city,
            "provider_coordinates": top_provider.get("coordinates"),
            "client_coordinates": {
                "lat": client_lat,
                "lng": client_lng,
            } if client_lat is not None and client_lng is not None else None,
        },''',
        "mukhtar: add client_coordinates to booking",
    )
else:
    print("  ⚠️  mukhtar_agent.py not found")

# ── 4. main.py — add provider location and registration endpoints ─────────────
print("\n[4/4] Patching main.py — add provider location + registration endpoints...")
main_path = BACKEND / "main.py"
if main_path.exists():
    shutil.copy(main_path, main_path.with_suffix(".py.bak"))
    content = main_path.read_text(encoding="utf-8")
    
    # Check if already patched
    if "_provider_locations" in content:
        print("  ⚠️  main.py already has location routes — skipping")
    else:
        # Add in-memory store after _jobs import
        content = content.replace(
            "from orchestrator import run_orchestration, get_booking, get_all_bookings, _jobs",
            "from orchestrator import run_orchestration, get_booking, get_all_bookings, _jobs\n\n# Live provider location store (keyed by provider_id)\n_provider_locations: dict = {}"
        )
        
        # Add endpoints before the `if __name__ == '__main__':` block
        location_routes = '''

# ─── Provider Registration (from Flutter ProviderRegistrationScreen) ──────────
@app.post("/provider/register")
async def register_provider(body: dict):
    provider_id = body.get("provider_id")
    if not provider_id:
        name = body.get("provider_name", "provider").lower().replace(" ", "_")[:8]
        import hashlib
        h = hashlib.md5(name.encode()).hexdigest()[:4].upper()
        provider_id = f"PRV-{name[:6].upper()}-{h}"
    body["provider_id"] = provider_id
    body["registered_at"] = datetime.datetime.utcnow().isoformat()
    return {"success": True, "provider_id": provider_id}


# ─── Provider Live Location Push ──────────────────────────────────────────────
@app.post("/provider/location")
async def update_provider_location(body: dict):
    """Provider app pushes GPS every 8s. Client map polls GET /provider/location/{id}"""
    provider_id = body.get("provider_id")
    lat = body.get("lat")
    lng = body.get("lng")
    if not provider_id or lat is None or lng is None:
        raise HTTPException(status_code=400, detail="provider_id, lat, lng required")
    _provider_locations[provider_id] = {
        "lat": lat, "lng": lng,
        "timestamp": body.get("timestamp", datetime.datetime.utcnow().isoformat()),
    }
    # Keep active job locations current
    for job in _jobs.values():
        if job.get("provider_id") == provider_id:
            job.setdefault("location", {})["provider_live_coordinates"] = {"lat": lat, "lng": lng}
    return {"success": True}


# ─── Provider Live Location Fetch ─────────────────────────────────────────────
@app.get("/provider/location/{provider_id}")
async def get_provider_location(provider_id: str):
    """Client map polls this every 4s to update provider marker."""
    loc = _provider_locations.get(provider_id)
    if not loc:
        raise HTTPException(status_code=404, detail="No live location for this provider")
    return loc


# ─── Distance & ETA Calculator ────────────────────────────────────────────────
@app.get("/distance")
async def calculate_distance(lat1: float, lng1: float, lat2: float, lng2: float):
    import math
    R = 6371.0
    r1, g1, r2, g2 = map(math.radians, [lat1, lng1, lat2, lng2])
    dlat, dlng = r2 - r1, g2 - g1
    a = math.sin(dlat/2)**2 + math.cos(r1)*math.cos(r2)*math.sin(dlng/2)**2
    dist_km = R * 2 * math.asin(math.sqrt(a))
    eta = max(5, int((dist_km / 30) * 60) + 5)
    return {"distance_km": round(dist_km, 2), "eta_minutes": eta, "speed_assumed_kmh": 30}

'''
        content = content.replace(
            '\nif __name__ == "__main__":',
            location_routes + '\nif __name__ == "__main__":'
        )
        main_path.write_text(content, encoding="utf-8")
        print("  ✅  [main.py: location routes] applied")
else:
    print("  ⚠️  main.py not found")

print("\n✅ All patches applied. Backups saved as *.py.bak")
print("   Restart the backend: uvicorn main:app --reload\n")

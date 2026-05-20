"""
KHOJI Agent — Provider Discovery & Ranking
Role: Search, filter, score and rank service providers.
Uses: Google Maps Places API + Internal Provider DB + Weather Context
Scoring Formula: Distance(30) + Rating(25) + Availability(20) + ResponseRate(15) + Verification(10) = 100
"""
import httpx
import os
import json
import math
import asyncio
from pathlib import Path

# Load internal provider database
_DB_PATH = Path(__file__).parent.parent / "data" / "providers_db.json"

def _load_providers_db() -> list:
    try:
        with open(_DB_PATH, "r", encoding="utf-8") as f:
            return json.load(f)["providers"]
    except Exception:
        return []

def _haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate km distance between two GPS coordinates"""
    R = 6371.0
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))

def _score_provider(provider: dict, urgency_score: int, user_lat: float = None, user_lon: float = None) -> float:
    """
    Agentic scoring — agent REASONS about the best provider.
    Score = Distance(30) + Rating(25) + Availability(20) + ResponseRate(15) + Verification(10)
    """
    score = 0
    reasoning = []

    # 1. Distance Score (max 30)
    if user_lat and user_lon and provider.get("coordinates"):
        dist = _haversine_distance(
            user_lat, user_lon,
            provider["coordinates"]["lat"],
            provider["coordinates"]["lng"]
        )
        provider["_distance_km"] = round(dist, 1)
        dist_score = max(0, 30 - (dist * 3))  # lose 3 pts per km
        score += dist_score
        reasoning.append(f"dist {dist:.1f}km→{dist_score:.0f}/30")
    else:
        # No GPS — give average score
        provider["_distance_km"] = round(2.0 + (hash(provider["provider_id"]) % 50) / 10, 1)
        score += 18
        reasoning.append("dist estimated→18/30")

    # 2. Rating Score (max 25)
    rating = provider.get("rating", 0)
    rating_score = ((rating - 1) / 4) * 25  # 1→0, 5→25
    score += rating_score
    reasoning.append(f"rating {rating}→{rating_score:.0f}/25")

    # 3. Availability Score (max 20)
    avail = provider.get("availability", {})
    avail_score = 0
    if avail.get("available_today"):
        avail_score += 15
    if urgency_score >= 8 and avail.get("accepts_emergency"):
        avail_score += 5  # Bonus for emergency capability
    elif urgency_score < 8 and not avail.get("accepts_emergency"):
        avail_score += 3  # Normal booking, no emergency needed
    score += avail_score
    reasoning.append(f"avail→{avail_score}/20")

    # 4. Response Rate Score (max 15)
    resp_rate = provider.get("response_rate", 0.7)
    resp_score = resp_rate * 15
    score += resp_score
    reasoning.append(f"resp {resp_rate:.0%}→{resp_score:.0f}/15")

    # 5. Verification Score (max 10)
    verif = provider.get("verification", {})
    verif_level = verif.get("level", "NONE")
    if verif_level == "KHIDMATGAR_VERIFIED":
        verif_score = 10
    elif verif_level == "GOOGLE_VERIFIED":
        verif_score = 7
    else:
        verif_score = 3
    score += verif_score
    reasoning.append(f"verif {verif_level}→{verif_score}/10")
    
    # 6. Live Registration Bonus (Critical Thinking - favor real app users over mock DB)
    if provider.get("_is_live_registered"):
        score += 15 # Huge bonus to guarantee they surface first
        reasoning.append(f"live_app_user_bonus→15")

    provider["_score"] = round(score, 1)
    provider["_score_breakdown"] = " | ".join(reasoning)
    return score


def _filter_by_service_and_location(providers: list, service_type: str, area: str, city: str) -> list:
    """Filter providers from internal DB matching service + location"""
    matched = []
    service_type_upper = service_type.upper() if service_type else "OTHER"
    city_lower = (city or "").lower()
    area_lower = (area or "").lower()

    for p in providers:
        # Service match
        if service_type_upper not in [s.upper() for s in p.get("service_categories", [])]:
            continue
        # City match (case-insensitive partial)
        provider_city = p.get("city", "").lower()
        is_live = p.get("_is_live_registered", False)
        
        # If city doesn't match and it's not a live app user, skip
        if not is_live and city_lower and city_lower not in provider_city and provider_city not in city_lower:
            continue
        # Area match — check areas_served list
        if area_lower:
            areas = [a.lower() for a in p.get("areas_served", [])]
            area_matched = any(area_lower in a or a in area_lower for a in areas)
            if area_matched:
                p["_area_match"] = True
                p["_area_match_bonus"] = 5  # bonus for exact area match
        matched.append(p)

    return matched


async def _get_weather_context(city: str) -> dict:
    """Fetch live weather — affects urgency reasoning"""
    try:
        weather_key = os.getenv("OPENWEATHER_API_KEY", "")
        if not weather_key:
            # Return realistic mock for Pakistan
            return {"temp_c": 38, "condition": "CLEAR", "humidity": 45, "source": "mock"}
        
        url = f"http://api.openweathermap.org/data/2.5/weather?q={city},PK&appid={weather_key}&units=metric"
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
            data = resp.json()
            return {
                "temp_c": round(data["main"]["temp"], 1),
                "condition": data["weather"][0]["main"].upper(),
                "humidity": data["main"]["humidity"],
                "source": "openweathermap_live"
            }
    except Exception:
        return {"temp_c": 36, "condition": "CLEAR", "humidity": 40, "source": "mock_fallback"}


async def _search_google_maps(service_type: str, area: str, city: str, api_key: str) -> list:
    """Call Google Maps Places API for real providers"""
    query = f"{service_type.replace('_', ' ')} services in {area or ''} {city or 'Pakistan'}".strip()
    url = f"https://maps.googleapis.com/maps/api/place/textsearch/json"
    params = {"query": query, "key": api_key, "language": "en", "region": "pk"}
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, params=params)
            data = resp.json()
            results = data.get("results", [])[:5]
            providers = []
            for i, r in enumerate(results):
                loc = r.get("geometry", {}).get("location", {})
                providers.append({
                    "provider_id": r.get("place_id", f"MAPS-{i+1}"),
                    "name": r.get("name", "Unknown"),
                    "business_name": r.get("name", "Unknown"),
                    "phone": "+92-3XX-XXXXXXX",
                    "rating": r.get("rating", 4.0),
                    "review_count": r.get("user_ratings_total", 0),
                    "response_rate": 0.85,
                    "distance_km": round(1.0 + i * 1.5, 1),
                    "eta_minutes": 15 + i * 10,
                    "pricing": {"estimated_total_pkr": 1500 + (i * 300), "visit_fee_pkr": 500},
                    "verification": {"level": "GOOGLE_VERIFIED"},
                    "availability": {"available_today": True, "accepts_emergency": i < 2, "next_slot": "Today ASAP"},
                    "coordinates": {"lat": loc.get("lat", 0), "lng": loc.get("lng", 0)},
                    "service_categories": [service_type],
                    "tags": [service_type, "GOOGLE_MAPS_RESULT"],
                    "city": city or "Unknown",
                    "_source": "google_maps_live"
                })
            return providers
    except Exception as e:
        return []


async def get_khoji_providers(service_type: str, city: str, urgency_score: int = 5, client_lat: float = None, client_lng: float = None) -> dict:
    """
    KHOJI's full agentic workflow:
    1. Observe: Extract service, location, urgency
    2. Reason: Decide search strategy (Maps + Internal DB)
    3. Act: Search both sources in parallel
    4. Evaluate: Score and rank all providers
    5. Adapt: Expand radius if too few results
    """
    api_key = os.getenv("GOOGLE_MAPS_API_KEY", "")
    area = ""
    
    observations = []
    observations.append(f"Service requested: {service_type}")
    observations.append(f"Location: {area}, {city}")
    observations.append(f"Urgency score: {urgency_score}/10")

    decisions = []
    tool_calls = []
    
    # --- Parallel: Weather + Provider Search ---
    weather_task = asyncio.create_task(_get_weather_context(city))
    
    all_providers = []
    
    # Search Google Maps if API key available
    if api_key and api_key not in ["", "your_google_maps_api_key", "dummy"]:
        decisions.append("Using Google Maps Places API for live provider search")
        maps_providers = await _search_google_maps(service_type, area, city, api_key)
        tool_calls.append({
            "tool": "google_maps_places_search",
            "input": f"{service_type} in {area} {city}",
            "output": f"{len(maps_providers)} results",
            "source": "google_maps_api"
        })
        all_providers.extend(maps_providers)
        observations.append(f"Google Maps returned {len(maps_providers)} providers")
    else:
        decisions.append("Google Maps API key not set — using internal provider database")

    # Always augment with internal DB
    internal_db = _load_providers_db()
    internal_matched = _filter_by_service_and_location(internal_db, service_type, area, city)
    tool_calls.append({
        "tool": "internal_provider_db_search",
        "input": f"{service_type} in {area}, {city}",
        "output": f"{len(internal_matched)} providers from KhidmatGar DB"
    })
    all_providers.extend(internal_matched)
    observations.append(f"Internal DB returned {len(internal_matched)} providers")

    # Dedup by provider_id
    seen = set()
    unique_providers = []
    for p in all_providers:
        pid = p.get("provider_id", "")
        if pid not in seen:
            seen.add(pid)
            score = _score_provider(p, urgency_score, user_lat=client_lat, user_lon=client_lng)
            if score > 30:  # Minimum quality threshold
                unique_providers.append(p)

    # --- RADIUS EXPANSION — if too few, try city-wide (HIFAZAT pattern) ---
    if len(unique_providers) < 2 and area:
        observations.append(f"Only {len(unique_providers)} providers found in {area}. Expanding to full {city}.")
        decisions.append(f"RADIUS_EXPANSION: Expanding search from {area} to full {city}")
        city_wide = _filter_by_service_and_location(internal_db, service_type, None, city)
        for p in city_wide:
            if p.get("provider_id") not in seen:
                seen.add(p["provider_id"])
                unique_providers.append(p)
        observations.append(f"After expansion: {len(unique_providers)} providers found")

    # --- Score and Rank ---
    weather = await weather_task
    
    # Weather affects urgency reasoning
    weather_note = ""
    if weather["temp_c"] > 40 and service_type == "AC_TECHNICIAN":
        weather_note = f"⚠️ HEAT ALERT: {weather['temp_c']}°C — AC demand is extremely high. Recommending fastest available provider."
        decisions.append("Weather context: Extreme heat → prioritizing fastest AC provider")
    
    for p in unique_providers:
        _score_provider(p, urgency_score)
        p["_distance_km"] = p.get("_distance_km", p.get("distance_km", 2.0))
        p["eta_minutes"] = max(10, int(p["_distance_km"] * 8) + 10)

    # Sort: urgency high → sort by eta; normal → sort by score
    if urgency_score >= 8:
        unique_providers.sort(key=lambda x: (x.get("eta_minutes", 999), -x.get("_score", 0)))
        decisions.append("Emergency mode: ranking by fastest ETA first")
    else:
        unique_providers.sort(key=lambda x: -x.get("_score", 0))
        decisions.append("Normal mode: ranking by composite score (distance+rating+availability+trust)")

    # Take top 3
    top_providers = unique_providers[:3]

    # Normalize output shape
    for p in top_providers:
        p["distance_km"] = p.get("_distance_km", 2.0)
        p["eta_minutes"] = p.get("eta_minutes", 25)
        p.setdefault("pricing", {})
        if "estimated_total_pkr" not in p["pricing"]:
            p["pricing"]["estimated_total_pkr"] = p["pricing"].get("hourly_rate_pkr", 1500)

    # Build reasoning trace
    if top_providers:
        top = top_providers[0]
        score_detail = top.get("_score_breakdown", "N/A")
        reasoning = (
            f"KHOJI searched {len(unique_providers)} providers for '{service_type}' in {area or city}. "
            f"Top pick: {top.get('business_name', top.get('name'))} "
            f"(Score: {top.get('_score', 0):.0f}/100 | {score_detail}). "
            f"Ranked {len(top_providers)} providers. "
            f"Weather: {weather['temp_c']}°C {weather['condition']}. "
            + (weather_note if weather_note else "")
        )
    else:
        reasoning = (
            f"KHOJI searched internal DB and Google Maps for '{service_type}' in {city}. "
            f"No providers found. HIFAZAT fallback protocol activated."
        )

    return {
        "providers": top_providers,
        "weather_context": weather,
        "tool_calls": tool_calls,
        "observations": observations,
        "decisions": decisions,
        "total_searched": len(unique_providers),
        "reasoning_trace": reasoning
    }

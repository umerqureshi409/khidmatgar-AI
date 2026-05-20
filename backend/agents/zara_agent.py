"""
ZARA Agent — Intent Parser
Role: Observe user input, reason about intent, extract structured data.
Model: gemini-1.5-flash (fastest, lowest latency for NLP)
"""
import os
try:
    from google import genai as genai_new
    _USE_NEW_SDK = True
except ImportError:
    import google.generativeai as genai
    _USE_NEW_SDK = False
import json
import re

def get_zara_intent(user_message: str, chat_history: list = None, client_lat: float = None, client_lng: float = None) -> dict:
    api_key = os.getenv("GEMINI_API_KEY", "")
    
    # --- Observation Phase ---
    observation = f"User said: '{user_message}' | Length: {len(user_message)} chars | Contains Urdu chars: {bool(re.search(r'[\u0600-\u06FF]', user_message))}"
    
    # Fallback if no key
    if not api_key or api_key in ["", "dummy_key", "your_api_key"]:
        return _build_fallback_intent(user_message, "API key not configured")

    try:
        if _USE_NEW_SDK:
            client = genai_new.Client(api_key=api_key)
        else:
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel('gemini-2.5-flash')

        history_str = ""
        if chat_history:
            history_str = "\nChat Context:\n"
            for msg in chat_history[:-1]:
                history_str += f"- {msg['role']}: {msg['content']}\n"
        
        prompt = f"""You are ZARA, the multilingual Intent Parser agent for KhidmatGar — Pakistan's AI-powered service platform.
Your job: Observe the user's message and extract structured intent with full reasoning. You MUST remember the context from previous messages if the user's current message is a follow-up (like only providing a location after being asked).
{history_str}
Current User Message: "{user_message}"

Think step by step:
1. Detect the language (look for Urdu characters, common Roman Urdu words, English words)
2. Identify the service being requested 
3. Extract location — area (neighborhood/sector like G-11, F-7, DHA Phase 2, Gulshan) and city (Islamabad, Karachi, Lahore, Rawalpindi, Peshawar, Quetta, etc.)
4. Assess time urgency (emergency keywords: fire, burst, emergency, foron, abhi, foran = score 9-10; normal = 4-6; future = 1-3)
5. Extract any time preference (today, kal, tomorrow, etc.)

Respond in STRICT JSON (no markdown, no extra text):
{{
  "detected_language": "URDU|ROMAN_URDU|ENGLISH|MIXED",
  "service_type": "AC_TECHNICIAN|ELECTRICIAN|PLUMBER|CARPENTER|PAINTER|CLEANER|TUTOR|DRIVER|COOK|SECURITY_GUARD|BEAUTY_SERVICES|PEST_CONTROL|APPLIANCE_REPAIR|MECHANIC|GARDENER|OTHER",
  "service_keywords": ["list", "of", "key", "words", "found"],
  "location": {{
    "area": "exact area/sector/neighborhood extracted or null",
    "city": "city name in English or null",
    "confidence": 0.0
  }},
  "time_preference": "NOW|TODAY|TOMORROW_MORNING|TOMORROW|NEXT_WEEK|FLEXIBLE",
  "urgency": {{
    "score": 5,
    "reason": "why this urgency level"
  }},
  "clarification_needed": false,
  "reasoning_trace": "Step-by-step: 1) Language detected as X because... 2) Service is X because user said... 3) Location is X because... 4) Urgency is X because..."
}}"""

        if _USE_NEW_SDK:
            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=prompt
            )
            raw = response.text.strip()
        else:
            response = model.generate_content(prompt)
            raw = response.text.strip()
        # Remove markdown code blocks if present
        raw = re.sub(r'```json\s*', '', raw)
        raw = re.sub(r'```\s*', '', raw)
        raw = raw.strip()
        
        parsed = json.loads(raw)
        
        # Validation & normalization
        if not parsed.get("location", {}).get("city"):
            parsed["location"]["city"] = _infer_city(user_message)
            
        if not parsed.get("service_type"):
            parsed["service_type"] = "OTHER"
            
        # If no city was inferred and we don't have GPS coordinates, we MUST ask for location
        has_city = parsed.get("location", {}).get("city")
        if not has_city and (client_lat is None or client_lng is None):
            parsed["clarification_needed"] = True

        parsed["_observation"] = observation
        parsed["_model"] = "gemini-2.5-flash"
        return parsed

    except json.JSONDecodeError as e:
        return _build_fallback_intent(user_message, f"JSON parse error: {str(e)}")
    except Exception as e:
        err = str(e)
        # If model not found, try alternative
        if "404" in err or "not found" in err:
            return _try_alternative_model(user_message, api_key, observation)
        return _build_fallback_intent(user_message, err)


def _try_alternative_model(user_message: str, api_key: str, observation: str) -> dict:
    """Try gemini-2.0-flash if primary model fails"""
    try:
        if _USE_NEW_SDK:
            client = genai_new.Client(api_key=api_key)
        else:
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel('gemini-3-flash')
        prompt = f"""Extract service intent from: "{user_message}"
Return JSON only: {{"detected_language": "ROMAN_URDU|URDU|ENGLISH|MIXED", "service_type": "AC_TECHNICIAN|ELECTRICIAN|PLUMBER|CARPENTER|PAINTER|CLEANER|OTHER", "location": {{"area": null, "city": null, "confidence": 0.5}}, "time_preference": "TODAY", "urgency": {{"score": 5, "reason": "normal"}}, "clarification_needed": false, "reasoning_trace": "brief"}}"""
        if _USE_NEW_SDK:
            response = client.models.generate_content(model='gemini-2.5-flash', contents=prompt)
        else:
            response = model.generate_content(prompt)
        raw = re.sub(r'```[a-z]*\s*', '', response.text).strip()
        parsed = json.loads(raw)
        parsed["_model"] = "gemini-3-flash (fallback)"
        parsed["_observation"] = observation
        if not parsed.get("location", {}).get("city"):
            parsed["location"]["city"] = _infer_city(user_message)
        return parsed
    except Exception as e2:
        return _build_fallback_intent(user_message, f"All models failed: {str(e2)}")


def _infer_city(message: str) -> str:
    """Heuristic city inference from message text — covers major Pakistan cities & areas"""
    msg = message.lower()
    cities = {
        "Islamabad": ["islamabad", "isb", "g-11", "g-10", "g-9", "g-8", "f-7", "f-6", "f-8", "i-8", "i-9", "i-10", "e-7", "e-11", "b-17", "d-12", "e-12"],
        "Rawalpindi": ["rawalpindi", "rwp", "pindi", "bahria town", "chaklala", "satellite town", "gulraiz"],
        "Karachi": ["karachi", "khi", "dha karachi", "gulshan", "nazimabad", "korangi", "clifton", "saddar", "defence", "north nazimabad", "federal b area", "malir", "lyari"],
        "Lahore": ["lahore", "lhr", "gulberg", "johar town", "model town", "dha lahore", "bahria lahore", "iqbal town", "garden town", "wapda town", "faisal town"],
        "Peshawar": ["peshawar", "psh", "hayatabad", "university town", "phase 5 peshawar"],
        "Quetta": ["quetta", "satellite town quetta"],
        "Faisalabad": ["faisalabad", "lyallpur", "peoples colony"],
        "Multan": ["multan", "cantt multan"],
        "Sialkot": ["sialkot"],
        "Gujranwala": ["gujranwala"],
        "Hyderabad": ["hyderabad", "latifabad", "qasimabad"],
        "Kotri": ["kotri", "khanzada"],
        "Abbottabad": ["abbottabad"],
        "Sukkur": ["sukkur"],
        "Larkana": ["larkana"],
        "Gwadar": ["gwadar"],
    }
    for city, keywords in cities.items():
        for kw in keywords:
            if kw in msg:
                return city
    return ""  # Default to capital


def _build_fallback_intent(user_message: str, error: str) -> dict:
    """Smart keyword-based fallback when AI is unavailable"""
    msg = user_message.lower()
    
    # Service detection
    service_map = {
        "AC_TECHNICIAN": ["ac", "air condition", "cooling", "heat", "garam", "thanda", "inverter"],
        "ELECTRICIAN": ["electric", "bijli", "light", "wiring", "short circuit", "socket", "fan"],
        "PLUMBER": ["plumb", "pipe", "nali", "pani", "water", "leak", "drain", "sewage", "nalka"],
        "CARPENTER": ["carpenter", "wood", "darwaza", "door", "furniture", "almari", "wardrobe"],
        "PAINTER": ["paint", "rang", "wall", "wall paint", "interior"],
        "CLEANER": ["clean", "safai", "sweep", "maid", "domestic"],
        "PEST_CONTROL": ["pest", "insect", "cockroach", "rat", "spray", "keeray"],
        "APPLIANCE_REPAIR": ["fridge", "washing machine", "microwave", "appliance", "repair", "machine"],
    }
    
    detected_service = "OTHER"
    for service, keywords in service_map.items():
        if any(kw in msg for kw in keywords):
            detected_service = service
            break
    
    # Language detection
    has_urdu = bool(re.search(r'[\u0600-\u06FF]', user_message))
    roman_urdu_words = ["chahiye", "wala", "mujhe", "mein", "hai", "hain", "karo", "do", "kal", "abhi", "foron", "zaroor", "please"]
    is_roman = any(w in msg for w in roman_urdu_words)
    
    if has_urdu:
        lang = "URDU"
    elif is_roman:
        lang = "ROMAN_URDU"
    else:
        lang = "ENGLISH"
    
    # Urgency detection
    emergency_words = ["urgent", "emergency", "immediately", "abhi", "foron", "jaldi", "burst", "fire", "help"]
    urgency_score = 9 if any(w in msg for w in emergency_words) else 5
    
    return {
        "detected_language": lang,
        "service_type": detected_service,
        "service_keywords": [w for kws in service_map.values() for w in kws if w in msg],
        "location": {
            "area": None,
            "city": _infer_city(user_message),
            "confidence": 0.4
        },
        "time_preference": "TODAY" if urgency_score >= 8 else "FLEXIBLE",
        "urgency": {"score": urgency_score, "reason": "keyword-based heuristic (AI fallback active)"},
        "clarification_needed": detected_service == "OTHER",
        "reasoning_trace": f"FALLBACK MODE: {error}. Keyword-based extraction: service={detected_service}, lang={lang}",
        "_model": "heuristic_fallback",
        "_observation": f"AI unavailable. Fallback heuristic applied to: '{user_message}'"
    }

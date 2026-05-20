"""
KhidmatGar Master Orchestrator
Chains all 5 agents: ZARA → KHOJI → MUKHTAR → YAKEEN → HIFAZAT
Implements true agentic pattern: Observe → Reason → Decide → Act → Evaluate → Adapt
"""
import uuid
import datetime
import os
import asyncio
import traceback

from agents.zara_agent import get_zara_intent
from agents.khoji_agent import get_khoji_providers
from agents.mukhtar_agent import run_mukhtar_booking
from agents.yakeen_agent import run_yakeen_followup
from agents.hifazat_agent import run_hifazat_guard

# Firebase — optional, graceful if unavailable
# Firebase — optional, graceful if unavailable
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    import json

    if not firebase_admin._apps:
        _cred_json = os.getenv("FIREBASE_CREDENTIALS")
        if _cred_json:
            _cred = credentials.Certificate(json.loads(_cred_json))
        else:
            _cred_path = os.path.join(os.path.dirname(__file__), "firebase_credentials.json")
            _cred = credentials.Certificate(_cred_path)
        firebase_admin.initialize_app(_cred)
    _db = firestore.client() if firebase_admin._apps else None
except Exception:
    _db = None

# In-memory session store (replace with Redis in production)
_sessions: dict = {}
_bookings: dict = {}
_jobs: dict = {}


async def run_orchestration(user_message: str, session_id: str = None, platform: str = "flutter", client_lat: float = None, client_lng: float = None) -> dict:
    """
    Master orchestration pipeline.
    Returns full agentic response with trace, providers, booking, and follow-up.
    """
    if not session_id:
        session_id = str(uuid.uuid4())

    pipeline_start = datetime.datetime.utcnow()

    # Workplan (logged for Antigravity trace requirement)
    workplan = {
        "steps": ["ZARA:intent_parse", "KHOJI:provider_search", "MUKHTAR:booking", "YAKEEN:followup", "HIFAZAT:guard"],
        "session_id": session_id,
        "user_message": user_message,
        "started_at": pipeline_start.isoformat() + "Z",
        "platform": platform
    }

    zara_result = {}
    khoji_result = {"providers": [], "tool_calls": [], "reasoning_trace": ""}
    mukhtar_result = {"booking": None, "response_message": "", "trace": ""}
    yakeen_result = {"scheduled_actions": [], "trace": ""}
    hifazat_result = {"triggered": False, "trace": "HIFAZAT on standby."}
    final_message = ""
    current_agent = "ZARA"

    try:
        # Check if user is confirming a booking
        is_booking_action = user_message.startswith("SYSTEM_BOOK_PROVIDER:")
        is_rating_action = user_message.startswith("SYSTEM_RATING_SUBMITTED:")
        
        if is_rating_action:
            rating = float(user_message.split(":", 1)[1].strip())
            session_data = _sessions.get(session_id, {})
            last_booking_id = session_data.get("last_booking_id")
            booking = _bookings.get(last_booking_id) if last_booking_id else None
            
            # Simple YAKEEN response for rating
            if rating >= 4:
                final_message = f"🌟 Thank you for the amazing {rating}-star rating! We are glad you had a great experience with KhidmatGar."
            else:
                final_message = f"Thank you for your feedback. We noticed your {rating}-star rating. The HIFAZAT team will review this to ensure better service next time."
            
            yakeen_result = {"trace": f"YAKEEN observed a rating of {rating} and sent a thank you note."}
            return _build_response(session_id, final_message, "YAKEEN", [], booking, workplan, zara_result, khoji_result, mukhtar_result, yakeen_result, hifazat_result, pipeline_start)

        if is_booking_action:
            provider_id = user_message.split(":", 1)[1].strip()
            # Find the job
            job = None
            for jid, j in _jobs.items():
                if j.get("session_id") == session_id and j.get("status") == "BID_RECEIVED":
                    job = j
                    break
            
            if job:
                job["status"] = "CONFIRMED"
                job["booking_id"] = job.get("booking_id", job.get("job_id")) # Ensure booking_id exists
                _bookings[job["booking_id"]] = job
                
                # Fetch provider name and price from bids
                latest_bid = job["bids"][-1] if job.get("bids") else {}
                provider_name = latest_bid.get("provider_name", "Provider")
                price = latest_bid.get("price", "N/A")
                eta = latest_bid.get("eta_minutes", "N/A")

                final_message = f"Booking confirmed with {provider_name}! Estimated cost: PKR {price}. ETA: {eta} mins."
                
                # YAKEEN Follow-up
                current_agent = "YAKEEN"
                yakeen_result = run_yakeen_followup(job, _sessions.get(session_id, {}).get("last_zara", {}))
                
                # HIFAZAT check
                hifazat_result = run_hifazat_guard(providers=[], intent=_sessions.get(session_id, {}).get("last_zara", {}), booking=job)
                current_agent = "MUKHTAR"

                return _build_response(session_id, final_message, current_agent, [], job, workplan, {}, {}, {"booking": job, "response_message": final_message, "trace": "Job Confirmed"}, yakeen_result, hifazat_result, pipeline_start)
            else:
                final_message = "No pending bid found to confirm."
                return _build_response(session_id, final_message, "HIFAZAT", [], None, workplan, {}, {}, {}, {}, {}, pipeline_start)

        # ══════════════════════════════════════════════
        # ══════════════════════════════════════════════
        # STEP 1 — ZARA: Parse Intent
        # ══════════════════════════════════════════════
        current_agent = "ZARA"
        
        # Load session memory
        session_data = _sessions.get(session_id, {})
        chat_history = session_data.get("history", [])
        
        # Append user message
        chat_history.append({"role": "user", "content": user_message})
        if len(chat_history) > 6:
            chat_history = chat_history[-6:]
            
        _sessions.setdefault(session_id, {})["history"] = chat_history
        
        zara_result = get_zara_intent(user_message, chat_history, client_lat=client_lat, client_lng=client_lng)
        
        service_type = zara_result.get("service_type", "OTHER")
        lang = zara_result.get("detected_language", "ENGLISH")
        city = zara_result.get("location", {}).get("city")

        # Check if clarification needed (ambiguous service)
        if zara_result.get("clarification_needed") or service_type in ["OTHER", "UNKNOWN"]:
            hifazat_result = run_hifazat_guard(intent=zara_result, providers=None)
            if hifazat_result["triggered"]:
                return _build_response(
                    session_id=session_id,
                    user_message=hifazat_result["message"],
                    current_agent="HIFAZAT",
                    providers=[],
                    booking=None,
                    workplan=workplan,
                    zara=zara_result,
                    khoji=khoji_result,
                    mukhtar=mukhtar_result,
                    yakeen=yakeen_result,
                    hifazat=hifazat_result,
                    pipeline_start=pipeline_start
                )

        # ══════════════════════════════════════════════
        # STEP 2 — KHOJI: Provider Discovery & Ranking
        # ══════════════════════════════════════════════
        current_agent = "KHOJI"
        khoji_result = await get_khoji_providers(
            service_type=service_type, 
            city=city, 
            urgency_score=zara_result.get("urgency", {}).get("score", 5),
            client_lat=client_lat,
            client_lng=client_lng
        )
        providers = khoji_result.get("providers", [])

        # No providers found → HIFAZAT recovery
        if not providers:
            current_agent = "HIFAZAT"
            hifazat_result = run_hifazat_guard(
                providers=[],
                intent=zara_result,
                error_context="No providers found after radius expansion"
            )
            final_message = hifazat_result.get("message", _no_provider_msg(lang))
            return _build_response(
                session_id=session_id,
                user_message=final_message,
                current_agent="HIFAZAT",
                providers=[],
                booking=None,
                workplan=workplan,
                zara=zara_result,
                khoji=khoji_result,
                mukhtar=mukhtar_result,
                yakeen=yakeen_result,
                hifazat=hifazat_result,
                pipeline_start=pipeline_start
            )

        # Store session state for interactive booking
        _sessions[session_id] = {
            "last_providers": providers,
            "last_zara": zara_result
        }

        # ══════════════════════════════════════════════
        # STEP 3 — UI Presentation (MUKHTAR creates job)
        # ══════════════════════════════════════════════
        current_agent = "MUKHTAR"
        top_provider = providers[0]
        mukhtar_result = run_mukhtar_booking(top_provider, zara_result, session_id, client_lat=client_lat, client_lng=client_lng)
        booking_job = mukhtar_result.get("booking")
        
        if booking_job:
            _jobs[booking_job["booking_id"]] = booking_job
            _sessions[session_id]["last_booking_id"] = booking_job["booking_id"]
            
        final_message = mukhtar_result.get("response_message", "Providers have been notified. Waiting for bids...")

    except Exception as e:
        # HIFAZAT catches all unhandled errors
        tb = traceback.format_exc()
        hifazat_result = run_hifazat_guard(
            error=e,
            error_context=f"Pipeline error at {current_agent}: {str(e)}"
        )
        final_message = hifazat_result.get("message", _generic_error_msg(
            zara_result.get("detected_language", "ENGLISH") if zara_result else "ENGLISH"
        ))
        current_agent = "HIFAZAT"

    return _build_response(
        session_id=session_id,
        user_message=final_message,
        current_agent=current_agent,
        providers=khoji_result.get("providers", []),
        booking=mukhtar_result.get("booking"),
        workplan=workplan,
        zara=zara_result,
        khoji=khoji_result,
        mukhtar=mukhtar_result,
        yakeen=yakeen_result,
        hifazat=hifazat_result,
        pipeline_start=pipeline_start
    )


def _build_response(
    session_id, user_message, current_agent, providers, booking,
    workplan, zara, khoji, mukhtar, yakeen, hifazat, pipeline_start
) -> dict:
    """Build the complete Antigravity-trace-compatible response"""
    pipeline_end = datetime.datetime.utcnow()
    latency_ms = int((pipeline_end - pipeline_start).total_seconds() * 1000)

    # Collect all tool calls from agents
    all_tool_calls = khoji.get("tool_calls", [])

    # Build Antigravity-style trace
    antigravity_trace = {
        "session_id": session_id,
        "workplan": workplan,
        "task_plan": {
            "primary_goal": f"Book {zara.get('service_type', 'service')} for user",
            "sub_goals": ["Parse intent", "Find providers", "Score & rank", "Book", "Schedule follow-up"],
            "status": "COMPLETED" if booking else "PARTIAL"
        },
        "agent_observations": {
            "ZARA": zara.get("_observation", zara.get("reasoning_trace", "")),
            "KHOJI": " | ".join(khoji.get("observations", [])),
            "MUKHTAR": " | ".join(mukhtar.get("observations", [])),
            "YAKEEN": " | ".join(yakeen.get("observations", [])) if yakeen.get("observations") else "Monitoring booking",
            "HIFAZAT": " | ".join(hifazat.get("observations", [])) if hifazat.get("observations") else hifazat.get("trace", "")
        },
        "reasoning": {
            "zara_reasoning": zara.get("reasoning_trace", ""),
            "khoji_reasoning": khoji.get("reasoning_trace", ""),
            "mukhtar_reasoning": mukhtar.get("trace", ""),
            "provider_scoring": providers[0].get("_score_breakdown", "") if providers else "",
        },
        "decisions": {
            "ZARA": [],
            "KHOJI": khoji.get("decisions", []),
            "MUKHTAR": mukhtar.get("decisions", []),
            "YAKEEN": yakeen.get("decisions", []),
            "HIFAZAT": hifazat.get("recovery_actions", [])
        },
        "tool_calls": all_tool_calls,
        "action_execution": {
            "booking_created": booking.get("booking_id") if booking else None,
            "provider_notified": bool(booking),
            "user_confirmed": bool(booking),
            "follow_ups_scheduled": len(yakeen.get("scheduled_actions", [])),
            "hifazat_triggered": hifazat.get("triggered", False)
        },
        "error_recovery": {
            "hifazat_triggered": hifazat.get("triggered", False),
            "scenario": hifazat.get("scenario", "STANDBY"),
            "recovery_actions": hifazat.get("recovery_actions", [])
        },
        "final_outcome": {
            "status": "SUCCESS" if booking else "HIFAZAT_RECOVERY",
            "booking_id": booking.get("booking_id") if booking else None,
            "provider": booking.get("provider_name") if booking else None,
            "providers_found": len(providers),
            "total_latency_ms": latency_ms,
            "language_handled": zara.get("detected_language", "UNKNOWN"),
            "model_used": zara.get("_model", "unknown")
        }
    }

    return {
        # Flutter-facing fields
        "user_message": user_message,
        "current_agent": current_agent,
        "providers": providers,
        "booking_data": booking,
        "message_type": "BOOKING_CONFIRMED" if booking and booking.get("status") == "CONFIRMED" else "TEXT",
        "session_id": session_id,

        # Agent trace (visible in Live Agent Brain panel)
        "agent_trace": {
            "active_agent": current_agent,
            "zara_trace": zara.get("reasoning_trace", zara.get("_observation", "")),
            "khoji_trace": khoji.get("reasoning_trace", ""),
            "mukhtar_trace": mukhtar.get("trace", ""),
            "yakeen_trace": yakeen.get("trace", ""),
            "hifazat_trace": hifazat.get("trace") if hifazat.get("triggered") else None,
            "before_state": {"status": "PENDING", "providers_found": 0, "booking": "NONE"},
            "after_state": {
                "status": booking.get("status", "SEARCHING") if booking else "SEARCHING",
                "providers_found": len(providers),
                "booking": booking.get("booking_id", "NONE") if booking else "NONE"
            }
        },

        # Full Antigravity trace (for submission/logs)
        "antigravity_trace": antigravity_trace,
        "latency_ms": latency_ms
    }


def _save_to_firebase(booking: dict):
    """Save booking to Firestore — non-blocking, fails silently"""
    try:
        if _db:
            _db.collection("bookings").document(booking["booking_id"]).set(booking)
    except Exception:
        pass  # Firebase failure doesn't break the flow


def get_booking(booking_id: str) -> dict:
    return _bookings.get(booking_id)


def get_all_bookings() -> list:
    return list(_bookings.values())


def _no_provider_msg(lang: str) -> str:
    if lang in ["ROMAN_URDU", "MIXED"]:
        return "Maafi! Koi provider nahi mila. Wider area mein search kar raha hun."
    return "Sorry, no providers found. Searching in a wider area."


def _generic_error_msg(lang: str) -> str:
    if lang in ["ROMAN_URDU", "MIXED"]:
        return "Ek masla aa gaya. Main recover kar raha hun. Dobara try karein."
    return "A technical issue occurred. I've recovered. Please try again."

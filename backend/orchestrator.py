"""
KhidmatGar Master Orchestrator — v2.1 (Production Fixed)
Chains all 5 agents: ZARA → KHOJI → MUKHTAR → YAKEEN → HIFAZAT
Implements true agentic pattern: Observe → Reason → Decide → Act → Evaluate → Adapt

Fixes applied (v2.1):
  [BUG-01] SYSTEM_BOOK_PROVIDER — job lookup now matches by provider_id OR latest bid, not just session+status
  [BUG-02] _build_response — message_type is "PROVIDER_LIST" when providers found but no booking yet
  [BUG-07] Booking confirmation message now uses actual bid price from latest bid
  [BUG-10] Session history preserved and passed correctly after booking confirmation
  [BUG-11] Provider bid notification pushed to notification queue when BID_RECEIVED
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

# In-memory stores (replace with Redis in production)
_sessions: dict = {}
_bookings: dict = {}
_jobs: dict = {}

# Notification queue reference — populated by main.py; we import lazily to avoid circular
_notification_queues: dict = {}


def _push_provider_notification(provider_id: str, message: str, notif_type: str = "INFO"):
    """Push a notification into the shared in-memory queue (also used by main.py)."""
    if provider_id not in _notification_queues:
        _notification_queues[provider_id] = []
    _notification_queues[provider_id].append({
        "type": notif_type,
        "message": message,
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "read": False,
    })


async def run_orchestration(
    user_message: str,
    session_id: str = None,
    platform: str = "flutter",
    client_lat: float = None,
    client_lng: float = None,
) -> dict:
    """
    Master orchestration pipeline.
    Returns full agentic response with trace, providers, booking, and follow-up.
    """
    if not session_id:
        session_id = str(uuid.uuid4())

    pipeline_start = datetime.datetime.utcnow()

    workplan = {
        "steps": ["ZARA:intent_parse", "KHOJI:provider_search", "MUKHTAR:booking", "YAKEEN:followup", "HIFAZAT:guard"],
        "session_id": session_id,
        "user_message": user_message,
        "started_at": pipeline_start.isoformat() + "Z",
        "platform": platform,
    }

    zara_result = {}
    khoji_result = {"providers": [], "tool_calls": [], "reasoning_trace": ""}
    mukhtar_result = {"booking": None, "response_message": "", "trace": ""}
    yakeen_result = {"scheduled_actions": [], "trace": ""}
    hifazat_result = {"triggered": False, "trace": "HIFAZAT on standby."}
    final_message = ""
    current_agent = "ZARA"

    # Restore session history for language + context continuity
    session_data = _sessions.get(session_id, {})

    try:
        # ─── Rating Action ──────────────────────────────────────────
        is_rating_action = user_message.startswith("SYSTEM_RATING_SUBMITTED:")
        if is_rating_action:
            try:
                rating = float(user_message.split(":", 1)[1].strip())
            except ValueError:
                rating = 5.0

            last_booking_id = session_data.get("last_booking_id")
            booking = _bookings.get(last_booking_id) if last_booking_id else None

            if rating >= 4:
                final_message = (
                    f"🌟 Thank you for the {rating:.0f}-star rating! "
                    "We're thrilled you had a great experience with KhidmatGar. "
                    "Your feedback helps us maintain the highest professional standards."
                )
            elif rating >= 3:
                final_message = (
                    f"Thank you for your {rating:.0f}-star feedback. "
                    "We'll use this to help your provider improve. "
                    "Is there anything specific we can do better next time?"
                )
            else:
                final_message = (
                    f"We're sorry to hear about your {rating:.0f}-star experience. "
                    "The HIFAZAT quality team will personally review this booking "
                    "and reach out to ensure it doesn't happen again."
                )

            # Push notification to provider about the rating [BUG-11]
            if booking and booking.get("provider_id"):
                _push_provider_notification(
                    booking["provider_id"],
                    f"⭐ New rating received: {rating:.0f}/5 stars for booking {last_booking_id}.",
                    "RATING_RECEIVED",
                )

            yakeen_result = {
                "trace": f"YAKEEN observed a rating of {rating} and dispatched thank-you + provider feedback.",
                "scheduled_actions": [],
            }
            return _build_response(
                session_id, final_message, "YAKEEN", [], booking,
                workplan, zara_result, khoji_result, mukhtar_result, yakeen_result, hifazat_result,
                pipeline_start,
            )

        # ─── Booking Confirmation Action [BUG-01 FIX] ───────────────
        is_booking_action = user_message.startswith("SYSTEM_BOOK_PROVIDER:")
        if is_booking_action:
            # Extract the provider_id the client confirmed
            confirmed_provider_id = user_message.split(":", 1)[1].strip()

            # [BUG-01] Look for the CORRECT job: match session_id AND the specific provider bid
            # Priority: job with a bid from this provider; fallback: any BID_RECEIVED for session
            job = None
            matched_bid = None
            for jid, j in _jobs.items():
                if j.get("session_id") != session_id:
                    continue
                if j.get("status") not in ("BID_RECEIVED", "PENDING"):
                    continue
                bids = j.get("bids", [])
                # Find the exact bid from the confirmed provider
                for bid in bids:
                    if bid.get("provider_id") == confirmed_provider_id:
                        job = j
                        matched_bid = bid
                        break
                if job:
                    break

            # If no exact provider match, fall back to the most recent BID_RECEIVED job
            if not job:
                for jid, j in _jobs.items():
                    if j.get("session_id") == session_id and j.get("status") == "BID_RECEIVED":
                        job = j
                        matched_bid = j.get("bids", [{}])[-1] if j.get("bids") else {}
                        break

            if job and matched_bid:
                job["status"] = "CONFIRMED"
                # Ensure booking_id alias is set
                booking_id = job.get("booking_id") or job.get("job_id")
                job["booking_id"] = booking_id
                job["confirmed_at"] = datetime.datetime.utcnow().isoformat() + "Z"
                job["confirmed_provider_id"] = confirmed_provider_id

                # [BUG-07] Use the ACTUAL bid price, not the estimated_total_pkr from MUKHTAR
                provider_name = matched_bid.get("provider_name", "Provider")
                bid_price = matched_bid.get("price", matched_bid.get("amount", "N/A"))
                eta = matched_bid.get("eta_minutes", job.get("eta_minutes", "N/A"))

                # Overwrite pricing in the booking record with actual bid price
                try:
                    bid_price_num = float(str(bid_price).replace(",", "").replace("PKR", "").strip())
                    job["pricing"]["bid_amount_pkr"] = bid_price_num
                    job["pricing"]["estimated_total_pkr"] = bid_price_num
                except (ValueError, TypeError):
                    pass

                _bookings[booking_id] = job
                # Update session with confirmed booking
                _sessions[session_id]["last_booking_id"] = booking_id

                # [BUG-11] Notify provider of booking confirmation
                _push_provider_notification(
                    confirmed_provider_id,
                    (
                        f"🎉 NEW BOOKING CONFIRMED!\n"
                        f"Job ID: {booking_id}\n"
                        f"Service: {job.get('service_type', 'Service')}\n"
                        f"Your bid of PKR {bid_price} was accepted.\n"
                        f"Location: {job.get('location', {}).get('area', 'N/A')}, "
                        f"{job.get('location', {}).get('city', 'N/A')}\n"
                        f"Please proceed to the client's location."
                    ),
                    "NEW_BOOKING",
                )

                # [BUG-07] Build confirmation message with REAL bid price
                lang = session_data.get("last_zara", {}).get("detected_language", "ENGLISH")
                final_message = _build_confirmation_message(
                    lang=lang,
                    provider_name=provider_name,
                    bid_price=bid_price,
                    eta=eta,
                    booking_id=booking_id,
                    slot=job.get("slot", "Today ASAP"),
                    phone=job.get("provider_phone", ""),
                )

                # [BUG-10] Restore intent for YAKEEN/HIFAZAT
                last_zara = session_data.get("last_zara", {})
                current_agent = "YAKEEN"
                yakeen_result = run_yakeen_followup(job, last_zara)
                hifazat_result = run_hifazat_guard(
                    providers=[], intent=last_zara, booking=job
                )
                current_agent = "MUKHTAR"

                # Save booking to Firebase
                _save_to_firebase(job)

                return _build_response(
                    session_id, final_message, current_agent, [], job, workplan,
                    last_zara, {}, {"booking": job, "response_message": final_message, "trace": "Job Confirmed via Bid"},
                    yakeen_result, hifazat_result, pipeline_start,
                )
            else:
                final_message = (
                    "No pending bid found to confirm. "
                    "Please wait for a provider to send their bid, then confirm."
                )
                return _build_response(
                    session_id, final_message, "HIFAZAT", [], None,
                    workplan, {}, {}, {}, {}, {}, pipeline_start,
                )

        # ══════════════════════════════════════════════════════════
        # STEP 1 — ZARA: Parse Intent
        # ══════════════════════════════════════════════════════════
        current_agent = "ZARA"

        # Load + update chat history [BUG-10]
        chat_history = session_data.get("history", [])
        chat_history.append({"role": "user", "content": user_message})
        if len(chat_history) > 10:  # Keep last 10 messages for context
            chat_history = chat_history[-10:]
        _sessions.setdefault(session_id, {})["history"] = chat_history

        zara_result = get_zara_intent(
            user_message, chat_history, client_lat=client_lat, client_lng=client_lng
        )

        service_type = zara_result.get("service_type", "OTHER")
        lang = zara_result.get("detected_language", "ENGLISH")
        city = zara_result.get("location", {}).get("city")
        area = zara_result.get("location", {}).get("area", "")

        # Check if clarification needed (ambiguous service or missing location)
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
                    pipeline_start=pipeline_start,
                )

        # ══════════════════════════════════════════════════════════
        # STEP 2 — KHOJI: Provider Discovery & Ranking
        # ══════════════════════════════════════════════════════════
        current_agent = "KHOJI"
        khoji_result = await get_khoji_providers(
            service_type=service_type,
            city=city,
            area=area,           # [BUG-03] Pass area explicitly
            urgency_score=zara_result.get("urgency", {}).get("score", 5),
            client_lat=client_lat,
            client_lng=client_lng,
        )
        providers = khoji_result.get("providers", [])

        # No providers found → HIFAZAT recovery
        if not providers:
            current_agent = "HIFAZAT"
            hifazat_result = run_hifazat_guard(
                providers=[],
                intent=zara_result,
                error_context="No providers found after radius expansion",
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
                pipeline_start=pipeline_start,
            )

        # Save session state [BUG-10] — include history reference
        _sessions[session_id].update({
            "last_providers": providers,
            "last_zara": zara_result,
        })

        # ══════════════════════════════════════════════════════════
        # STEP 3 — MUKHTAR: Create Job + Presentation Message
        # ══════════════════════════════════════════════════════════
        current_agent = "MUKHTAR"
        top_provider = providers[0]
        mukhtar_result = run_mukhtar_booking(
            top_provider, zara_result, session_id,
            client_lat=client_lat, client_lng=client_lng,
        )
        booking_job = mukhtar_result.get("booking")

        if booking_job:
            _jobs[booking_job["booking_id"]] = booking_job
            _sessions[session_id]["last_booking_id"] = booking_job["booking_id"]

        final_message = mukhtar_result.get(
            "response_message", "Providers have been notified. Waiting for bids..."
        )

    except Exception as e:
        tb = traceback.format_exc()
        print(f"[ORCHESTRATOR ERROR] {tb}")
        hifazat_result = run_hifazat_guard(
            error=e,
            error_context=f"Pipeline error at {current_agent}: {str(e)}",
        )
        final_message = hifazat_result.get(
            "message",
            _generic_error_msg(
                zara_result.get("detected_language", "ENGLISH") if zara_result else "ENGLISH"
            ),
        )
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
        pipeline_start=pipeline_start,
    )


# ─────────────────────────────────────────────────────────────
# Response Builder [BUG-02] — correct message_type
# ─────────────────────────────────────────────────────────────
def _build_response(
    session_id, user_message, current_agent, providers, booking,
    workplan, zara, khoji, mukhtar, yakeen, hifazat, pipeline_start,
) -> dict:
    """Build the complete Antigravity-trace-compatible response."""
    pipeline_end = datetime.datetime.utcnow()
    latency_ms = int((pipeline_end - pipeline_start).total_seconds() * 1000)

    all_tool_calls = khoji.get("tool_calls", [])

    # [BUG-02] Determine message_type correctly
    if booking and booking.get("status") == "CONFIRMED":
        message_type = "BOOKING_CONFIRMED"
    elif providers and not booking:
        message_type = "PROVIDER_LIST"   # Flutter needs this to show provider panel
    else:
        message_type = "TEXT"

    antigravity_trace = {
        "session_id": session_id,
        "workplan": workplan,
        "task_plan": {
            "primary_goal": f"Book {zara.get('service_type', 'service')} for user",
            "sub_goals": ["Parse intent", "Find providers", "Score & rank", "Book", "Schedule follow-up"],
            "status": "COMPLETED" if booking else "PARTIAL",
        },
        "agent_observations": {
            "ZARA": zara.get("_observation", zara.get("reasoning_trace", "")),
            "KHOJI": " | ".join(khoji.get("observations", [])),
            "MUKHTAR": " | ".join(mukhtar.get("observations", [])),
            "YAKEEN": " | ".join(yakeen.get("observations", [])) if yakeen.get("observations") else "Monitoring booking",
            "HIFAZAT": " | ".join(hifazat.get("observations", [])) if hifazat.get("observations") else hifazat.get("trace", ""),
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
            "HIFAZAT": hifazat.get("recovery_actions", []),
        },
        "tool_calls": all_tool_calls,
        "action_execution": {
            "booking_created": booking.get("booking_id") if booking else None,
            "provider_notified": bool(booking),
            "user_confirmed": bool(booking),
            "follow_ups_scheduled": len(yakeen.get("scheduled_actions", [])),
            "hifazat_triggered": hifazat.get("triggered", False),
        },
        "error_recovery": {
            "hifazat_triggered": hifazat.get("triggered", False),
            "scenario": hifazat.get("scenario", "STANDBY"),
            "recovery_actions": hifazat.get("recovery_actions", []),
        },
        "final_outcome": {
            "status": "SUCCESS" if booking else "HIFAZAT_RECOVERY",
            "booking_id": booking.get("booking_id") if booking else None,
            "provider": booking.get("provider_name") if booking else None,
            "providers_found": len(providers),
            "total_latency_ms": latency_ms,
            "language_handled": zara.get("detected_language", "UNKNOWN"),
            "model_used": zara.get("_model", "unknown"),
        },
    }

    return {
        # Flutter-facing fields
        "user_message": user_message,
        "current_agent": current_agent,
        "providers": providers,
        "booking_data": booking,
        "message_type": message_type,   # [BUG-02] fixed
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
                "booking": booking.get("booking_id", "NONE") if booking else "NONE",
            },
        },

        # Full Antigravity trace
        "antigravity_trace": antigravity_trace,
        "latency_ms": latency_ms,
    }


def _build_confirmation_message(
    lang: str,
    provider_name: str,
    bid_price,
    eta,
    booking_id: str,
    slot: str,
    phone: str,
) -> str:
    """[BUG-07] Build confirmation message using the ACTUAL bid price."""
    price_str = f"PKR {bid_price:,.0f}" if isinstance(bid_price, (int, float)) else f"PKR {bid_price}"
    if lang == "URDU":
        return (
            f"✅ بکنگ کنفرم!\n\n"
            f"🆔 بکنگ نمبر: {booking_id}\n"
            f"👷 سروس دہندہ: {provider_name}\n"
            f"📅 وقت: {slot}\n"
            f"⏱️ متوقع آمد: {eta} منٹ\n"
            f"💰 مقررہ رقم: {price_str}\n"
            f"📞 فون: {phone}\n\n"
            f"ادائیگی: نقد بوقت سروس\n"
            f"کوئی مسئلہ ہو تو بتائیں۔"
        )
    elif lang in ("ROMAN_URDU", "MIXED"):
        return (
            f"✅ Booking Confirm Ho Gayi!\n\n"
            f"🆔 Booking ID: {booking_id}\n"
            f"👷 Provider: {provider_name}\n"
            f"📅 Slot: {slot}\n"
            f"⏱️ ETA: {eta} minute mein pahunchenge\n"
            f"💰 Agreed Amount: {price_str}\n"
            f"📞 Phone: {phone}\n\n"
            f"Payment: Cash on delivery\n"
            f"Koi masla ho to batayen!"
        )
    else:
        return (
            f"✅ Booking Confirmed!\n\n"
            f"🆔 Booking ID: {booking_id}\n"
            f"👷 Provider: {provider_name}\n"
            f"📅 Slot: {slot}\n"
            f"⏱️ ETA: {eta} minutes\n"
            f"💰 Agreed Amount: {price_str}\n"
            f"📞 Phone: {phone}\n\n"
            f"Payment: Cash on delivery\n"
            f"Need anything else? I'm here to help!"
        )


def _save_to_firebase(booking: dict):
    """Save booking to Firestore — non-blocking, fails silently."""
    try:
        if _db:
            _db.collection("bookings").document(booking["booking_id"]).set(booking)
    except Exception:
        pass


def get_booking(booking_id: str) -> dict:
    return _bookings.get(booking_id)


def get_all_bookings() -> list:
    return list(_bookings.values())


def get_jobs() -> dict:
    return _jobs


def get_notification_queues() -> dict:
    return _notification_queues


def _no_provider_msg(lang: str) -> str:
    if lang in ["ROMAN_URDU", "MIXED"]:
        return "Maafi! Koi provider nahi mila. Wider area mein search kar raha hun."
    return "Sorry, no providers found. Searching in a wider area."


def _generic_error_msg(lang: str) -> str:
    if lang in ["ROMAN_URDU", "MIXED"]:
        return "Ek masla aa gaya. Main recover kar raha hun. Dobara try karein."
    return "A technical issue occurred. I've recovered. Please try again."

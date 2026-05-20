"""
MUKHTAR Agent — Professional Booking Orchestration & Provider Engagement
Role: Execute bookings professionally, notify providers with accountability,
      generate receipts, handle booking conflicts with expertise.
      Act like an experienced Booking Manager with deep industry knowledge.
Observes: Provider data + User context + Availability matrix
Reasons: Should we auto-book or ask confirmation? (experienced decision-making)
Decides: Booking slot, confirmation mode, provider matching
Acts: Creates booking record, professional provider notification, service initialization
"""
import uuid
import datetime
import os


def run_mukhtar_booking(top_provider: dict, intent: dict, session_id: str, client_lat: float = None, client_lng: float = None) -> dict:
    """
    MUKHTAR's professional decision pipeline:
    1. Observe: Provider availability, reliability score, service capacity
    2. Reason: Autonomous booking (experienced provider) vs. confirmation
    3. Act: Create professional booking record with full accountability
    4. Evaluate: Confirm success with professional tracking
    5. Optimize: Route through highest-reliability provider
    """
    urgency = intent.get("urgency", {}).get("score", 5)
    time_pref = intent.get("time_preference", "FLEXIBLE")
    service = intent.get("service_type", "SERVICE").replace("_", " ").title()
    lang = intent.get("detected_language", "ENGLISH")
    area = intent.get("location", {}).get("area", "your area")
    city = intent.get("location", {}).get("city", "your city")
    provider_name = top_provider.get("business_name") or top_provider.get("name", "Service Professional")
    provider_id = top_provider.get("provider_id", "UNKNOWN")

    # --- MUKHTAR PROFESSIONAL REASONING ---
    decisions = []
    observations = []

    provider_score = top_provider.get("_score", 0)
    provider_rating = top_provider.get("rating", 4.5)
    provider_experience = top_provider.get("experience_years", 0)
    provider_reviews = top_provider.get("review_count", 0)
    
    observations.append(f"Provider: {provider_name} (ID: {provider_id})")
    observations.append(f"Professional Score: {provider_score:.0f}/100 | Rating: {provider_rating:.1f}/5 | Experience: {provider_experience} years")
    observations.append(f"Customer Reviews: {provider_reviews} | Reliability: {top_provider.get('reliability_score', 85)}%")
    observations.append(f"Provider available: {top_provider.get('availability', {}).get('available_today', False)}")
    observations.append(f"Request Urgency: {urgency}/10 | Time Preference: {time_pref}")
    observations.append(f"Service Type: {service} | Location: {area}, {city}")

    # Professional decision: autonomous vs. confirmation
    if provider_score >= 85:
        booking_mode = "PROFESSIONAL_AUTO_BOOK"
        decisions.append(f"PROFESSIONAL DECISION: High-reliability provider (score: {provider_score:.0f}) - autonomous booking recommended")
    elif provider_score >= 70:
        booking_mode = "CONFIDENCE_AUTO_BOOK"
        decisions.append(f"CONFIDENCE BOOKING: Competent provider (score: {provider_score:.0f}) - proceeding with autonomous booking")
    elif urgency >= 7:
        booking_mode = "URGENT_AUTO_BOOK"
        decisions.append(f"URGENT SERVICE: Despite moderate provider score ({provider_score:.0f}), urgency level {urgency}/10 requires immediate booking")
    else:
        booking_mode = "STANDARD_AUTO_BOOK"
        decisions.append(f"STANDARD BOOKING: Provider score {provider_score:.0f} suitable for normal priority requests")

    # Determine professional time slot
    slot = _determine_professional_slot(time_pref, top_provider, urgency)
    decisions.append(f"Professional Time Slot: {slot}")

    # Generate booking ID with professional format
    date_str = datetime.datetime.now().strftime("%Y%m%d")
    booking_id = f"KG-{date_str}-{str(uuid.uuid4())[:4].upper()}"

    pricing = top_provider.get("pricing", {})
    estimated_cost = pricing.get("estimated_total_pkr", pricing.get("hourly_rate_pkr", 1500))
    visit_fee = pricing.get("visit_fee_pkr", 0)

    # Professional booking record with full accountability tracking
    booking = {
        "booking_id": booking_id,
        "job_id": booking_id, # Add job_id explicitly as some endpoints look for it
        "session_id": session_id,
        "status": "PENDING", # Changed from CONFIRMED to PENDING for bidding flow
        "booking_mode": booking_mode,
        "provider_id": provider_id,
        "provider_name": provider_name,
        "provider_phone": top_provider.get("phone", "+92-3XX-XXXXXXX"),
        "provider_rating": provider_rating,
        "provider_experience_years": provider_experience,
        "service_type": service,
        "slot": slot,
        "location": {
            "area": area,
            "city": city,
            "provider_coordinates": top_provider.get("coordinates"),
            "client_coordinates": {
                "lat": client_lat,
                "lng": client_lng,
            } if client_lat is not None and client_lng is not None else None,
        },
        "pricing": {
            "estimated_total_pkr": estimated_cost,
            "visit_fee_pkr": visit_fee,
            "payment_method": "CASH_ON_DELIVERY"
        },
        "provider_score_at_booking": provider_score,
        "provider_reliability": top_provider.get("reliability_score", 85),
        "created_at": datetime.datetime.utcnow().isoformat(),
        "eta_minutes": top_provider.get("eta_minutes", 30),
        "notifications_sent": {
            "client": True,
            "provider": True,
            "sms": False
        },
        "quality_tracking": {
            "started": True,
            "monitoring_active": True,
            "cancellation_allowed": True,
            "rating_required": True
        },
        "audit_trail": {
            "booked_by": "MUKHTAR_AGENT",
            "booking_mode": booking_mode,
            "provider_score": provider_score,
            "provider_reliability": top_provider.get("reliability_score", 85),
            "client_coordinates_available": client_lat is not None and client_lng is not None,
            "booking_timestamp": datetime.datetime.utcnow().isoformat()
        }
    }

    # Professional response message in client's language
    response_msg = _generate_professional_booking_confirmation(
        lang, provider_name, service, slot, booking_id, provider_experience
    )

    # Build professional MUKHTAR trace
    trace = (
        f"MUKHTAR (Booking Manager) evaluated provider {provider_name} with professional score {provider_score:.0f}/100, "
        f"rating {provider_rating:.1f}/5, and {provider_experience} years experience. "
        f"Decision: Professional autonomous booking for {service} service. "
        f"Job {booking_id} created for {slot}. "
        f"Status: PENDING (Waiting for Provider Bid). "
        f"Provider professionally notified with service details. "
        f"Client informed to wait for bids ✓"
    )

    return {
        "booking": booking,
        "response_message": response_msg,
        "decisions": decisions,
        "observations": observations,
        "trace": trace,
        "success": True,
        "professional_booking": True
    }


def _determine_professional_slot(time_pref: str, provider: dict, urgency: int) -> str:
    """Determine professionally appropriate time slot"""
    avail = provider.get("availability", {})
    next_slot = avail.get("next_slot", "Today - Immediate")
    
    if urgency >= 8:
        return "Today - URGENT (Immediate Priority)"
    
    slot_map = {
        "NOW": "Today - ASAP (Immediate Service)",
        "TODAY": next_slot if next_slot else "Today - Next Available Slot",
        "TOMORROW_MORNING": "Tomorrow - Morning Session (9:00 AM - 12:00 PM)",
        "TOMORROW": "Tomorrow - Afternoon Session (2:00 PM - 5:00 PM)",
        "NEXT_WEEK": "Next Week - Scheduled Service",
        "FLEXIBLE": next_slot if next_slot else "Today or Tomorrow - Professionally Optimized Slot",
    }
    return slot_map.get(time_pref, next_slot or "Today - Immediate")


def _generate_professional_booking_confirmation(
    lang: str, 
    provider_name: str, 
    service: str, 
    slot: str,
    booking_id: str,
    experience: int
) -> str:
    """Generate professional booking confirmation messages"""
    exp_text = f"with {experience} years of professional experience" if experience > 0 else "professional service provider"
    
    if lang == "URDU":
        return (
            f"⏳ تلاش جاری ہے! "
            f"ہم نے آپ کی {service} سروس کے لیے {provider_name} ({exp_text}) کو درخواست بھیج دی ہے۔ "
            f"براہ کرم ان کی بولی (Bid) کا انتظار کریں..."
        )
    elif lang == "ROMAN_URDU" or lang == "MIXED":
        return (
            f"⏳ Finding Providers... Hum ne {provider_name} {exp_text} ko aapki {service} request bhej di hai. "
            f"Please wait, unki bid aane wali hai..."
        )
    else:
        return (
            f"⏳ Finding Providers... We have sent your {service} request to {provider_name} {exp_text}. "
            f"Please wait while they review and send their bid..."
        )


def _generate_confirmation_message(booking: dict, lang: str, provider: dict) -> str:
    """Generate multilingual booking confirmation"""
    bid = booking["booking_id"]
    name = booking["provider_name"]
    slot = booking["slot"]
    eta = booking.get("eta_minutes", 30)
    cost = booking["pricing"]["estimated_total_pkr"]
    phone = booking.get("provider_phone", "")

    if lang == "URDU":
        return (
            f"✅ بکنگ کنفرم!\n\n"
            f"🆔 بکنگ نمبر: {bid}\n"
            f"👷 سروس دہندہ: {name}\n"
            f"📅 وقت: {slot}\n"
            f"⏱️ متوقع آمد: {eta} منٹ\n"
            f"💰 تخمینی قیمت: PKR {cost}\n"
            f"📞 فون: {phone}\n\n"
            f"ادائیگی: نقد بوقت سروس\n"
            f"کوئی مسئلہ ہو تو بتائیں — میں حل کروں گا۔"
        )
    elif lang == "ROMAN_URDU" or lang == "MIXED":
        return (
            f"✅ Booking Confirm Ho Gayi!\n\n"
            f"🆔 Booking ID: {bid}\n"
            f"👷 Provider: {name}\n"
            f"📅 Slot: {slot}\n"
            f"⏱️ ETA: {eta} minute mein pahunchenge\n"
            f"💰 Estimated Cost: PKR {cost}\n"
            f"📞 Phone: {phone}\n\n"
            f"Payment: Cash on delivery\n"
            f"Koi masla ho to batayen — main handle karunga!"
        )
    else:
        return (
            f"✅ Booking Confirmed!\n\n"
            f"🆔 Booking ID: {bid}\n"
            f"👷 Provider: {name}\n"
            f"📅 Slot: {slot}\n"
            f"⏱️ ETA: {eta} minutes\n"
            f"💰 Estimated Cost: PKR {cost}\n"
            f"📞 Phone: {phone}\n\n"
            f"Payment: Cash on delivery\n"
            f"Need anything else? I'm here to help!"
        )

"""
YAKEEN Agent — Follow-up, Scheduling, Satisfaction & Professional Accountability
Role: Schedule reminders, follow-up after service, collect ratings, verify completion.
      Act like an experienced Service Manager ensuring professional standards.
Observes: Booking data + time slot + customer satisfaction metrics
Reasons: What follow-ups are needed? How to maintain professional relationships?
Acts: Schedule reminders, post-service rating request, professional communication
"""
import datetime


def run_yakeen_followup(booking: dict, intent: dict) -> dict:
    """
    YAKEEN's professional follow-up pipeline:
    1. Calculate reminder times based on slot (professional timing)
    2. Schedule completion check-in with context-aware messaging
    3. Plan professional rating collection with feedback mechanism
    4. Handle edge cases (no-show, cancellation) professionally
    5. Maintain service quality standards through accountability
    """
    observations = []
    decisions = []
    scheduled_actions = []

    booking_id = booking.get("booking_id", "UNKNOWN")
    slot = booking.get("slot", "Today ASAP")
    eta = booking.get("eta_minutes", 30)
    provider_name = booking.get("provider_name", "Service Professional")
    provider_id = booking.get("provider_id", "UNKNOWN")
    urgency = intent.get("urgency", {}).get("score", 5)
    lang = intent.get("detected_language", "ENGLISH")
    service_type = intent.get("service_type", "SERVICE").replace("_", " ").title()

    now = datetime.datetime.utcnow()
    
    observations.append(f"Professional booking {booking_id} confirmed for: {slot}")
    observations.append(f"Service: {service_type} | Provider: {provider_name}")
    observations.append(f"Estimated arrival: {eta} minutes | Language: {lang}")
    observations.append(f"Service urgency level: {urgency}/10")

    # --- Professional Reminder Scheduling ---
    # Reminder 1: Provider on the way (professional courtesy)
    reminder_1_time = now + datetime.timedelta(minutes=5)
    scheduled_actions.append({
        "type": "PROFESSIONAL_ARRIVAL_REMINDER",
        "scheduled_at": reminder_1_time.isoformat() + "Z",
        "message_key": "provider_arriving_professional",
        "channel": "IN_APP",
        "priority": "HIGH",
        "tone": "professional_courtesy"
    })
    decisions.append("5-min arrival reminder scheduled (professional courtesy)")

    # Reminder 2: Professional check-in during service (30 minutes)
    checkin_time = now + datetime.timedelta(minutes=30)
    scheduled_actions.append({
        "type": "SERVICE_PROGRESS_CHECK",
        "scheduled_at": checkin_time.isoformat() + "Z",
        "message_key": "service_progress_check",
        "channel": "IN_APP",
        "priority": "MEDIUM",
        "tone": "professional_support"
    })
    decisions.append("30-min service progress check scheduled")

    # Reminder 3: Professional service completion verification (60 minutes)
    completion_time = now + datetime.timedelta(minutes=60)
    scheduled_actions.append({
        "type": "SERVICE_COMPLETION_VERIFICATION",
        "scheduled_at": completion_time.isoformat() + "Z",
        "message_key": "service_completed_check",
        "channel": "IN_APP",
        "priority": "HIGH",
        "provider_id": provider_id,
        "tone": "professional_verification"
    })
    decisions.append("60-min service completion verification scheduled")

    # Reminder 4: Professional quality rating request (90 minutes)
    rating_time = now + datetime.timedelta(minutes=90)
    scheduled_actions.append({
        "type": "PROFESSIONAL_QUALITY_RATING",
        "scheduled_at": rating_time.isoformat() + "Z",
        "message_key": "professional_rating_request",
        "channel": "IN_APP",
        "provider_id": provider_id,
        "priority": "HIGH",
        "tone": "professional_feedback_request"
    })
    decisions.append("Professional quality feedback request scheduled")

    # Emergency follow-up — faster check with professional accountability
    if urgency >= 8:
        emergency_check = now + datetime.timedelta(minutes=20)
        scheduled_actions.append({
            "type": "URGENT_SERVICE_RESOLUTION_CHECK",
            "scheduled_at": emergency_check.isoformat() + "Z",
            "message_key": "urgent_resolution_check",
            "channel": "IN_APP",
            "priority": "CRITICAL",
            "provider_id": provider_id,
            "tone": "professional_urgency"
        })
        decisions.append("Emergency: 20-minute professional resolution check scheduled")
        observations.append("HIGH URGENCY SERVICE: Accelerated professional oversight activated")

    # Professional no-show guard with accountability
    scheduled_actions.append({
        "type": "PROFESSIONAL_NO_SHOW_GUARD",
        "trigger_after_minutes": eta + 30,
        "action": "provider_accountability_check",
        "message_key": "provider_delayed_professional_check",
        "channel": "IN_APP",
        "provider_id": provider_id,
        "priority": "CRITICAL",
        "tone": "professional_accountability"
    })
    decisions.append(f"Professional no-show guard: alert at {eta + 30}min with provider accountability check")

    # Cancellation handling - professional protocol
    scheduled_actions.append({
        "type": "CANCELLATION_PROTOCOL",
        "trigger_event": "booking_cancelled",
        "action": "provider_professional_notification",
        "message_key": "cancellation_professional_notice",
        "priority": "HIGH",
        "provider_id": provider_id,
        "tone": "professional_cancellation"
    })
    decisions.append("Professional cancellation protocol armed: immediate provider notification")

    # Follow-up message (YAKEEN will communicate professionally)
    followup_msg = _build_professional_followup_message(
        lang, provider_name, service_type, eta, booking_id, urgency
    )

    trace = (
        f"YAKEEN (Service Manager) observed professional booking {booking_id} "
        f"for {service_type} with {eta}min ETA. "
        f"Activated comprehensive professional follow-up: {len(scheduled_actions)} scheduled actions. "
        f"Protocol: arrival reminder → progress check → completion verification → quality feedback → no-show guard. "
        f"Provider accountability and service quality standards maintained throughout engagement."
    )

    return {
        "scheduled_actions": scheduled_actions,
        "followup_message": followup_msg,
        "observations": observations,
        "decisions": decisions,
        "trace": trace,
        "reminders_count": len(scheduled_actions),
        "professional_mode": True,
        "service_quality_tracking": True
    }


def _build_professional_followup_message(
    lang: str, 
    provider_name: str, 
    service_type: str, 
    eta: int, 
    booking_id: str,
    urgency: int
) -> str:
    """Build professional, experienced follow-up messages"""
    if lang == "URDU":
        if urgency >= 8:
            return (
                f"🔴 فوری خدمت: {provider_name} شامل {service_type} کی فراہمی کے لیے متحرک ہے۔ "
                f"تقریباً {eta} منٹ میں آپ کے پاس پہنچیں گے۔ "
                f"سروس مکمل ہونے کے بعد ریٹنگ اور فیڈبیک درج کریں۔ "
                f"Ref: {booking_id}"
            )
        else:
            return (
                f"✓ {provider_name} آپ کی {service_type} درخواست قبول کر چکے ہیں۔ "
                f"تقریباً {eta} منٹ میں پہنچیں گے۔ "
                f"براہ کرم سروس کی مکمل تفصیل کے لیے ریٹنگ دیں۔ "
                f"Booking: {booking_id}"
            )
    elif lang == "ROMAN_URDU" or lang == "MIXED":
        if urgency >= 8:
            return (
                f"🔴 URGENT SERVICE ALERT: {provider_name} is actively en route for your {service_type}. "
                f"ETA ~{eta} minutes. Please rate and provide feedback upon completion. "
                f"Booking Ref: {booking_id}"
            )
        else:
            return (
                f"✓ {provider_name} has accepted your {service_type} request. "
                f"Estimated arrival: ~{eta} minutes. "
                f"Professional service quality tracking active. "
                f"Booking: {booking_id}"
            )
    else:
        if urgency >= 8:
            return (
                f"🔴 URGENT SERVICE: {provider_name} is actively providing your {service_type}. "
                f"Estimated arrival: ~{eta} minutes. "
                f"Please rate this service and provide detailed feedback. "
                f"Your rating helps us maintain professional standards. "
                f"Booking Ref: {booking_id}"
            )
        else:
            return (
                f"✓ Professional service confirmed: {provider_name} for {service_type}. "
                f"ETA ~{eta} minutes. "
                f"I'm monitoring this engagement for quality assurance. "
                f"Your rating is valuable for service improvement. "
                f"Booking: {booking_id}"
            )

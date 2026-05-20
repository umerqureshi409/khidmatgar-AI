# KhidmatGar — AI Service Orchestrator for Pakistan's Informal Economy

## 🎯 Executive Summary

**KhidmatGar** is a fully agentic, multilingual AI system that automates the complete lifecycle of service requests in Pakistan's informal economy. Using **Google Antigravity** as the core orchestration platform, it coordinates 5 specialized AI agents to understand user intent, discover providers, execute bookings, and manage follow-ups — all in Urdu, Roman Urdu, or English.

**Challenge**: Challenge 2: AI Service Orchestrator for Informal Economy  
**#AISeekho 2026 | Google Antigravity Hackathon**

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [How Antigravity Powers the System](#how-antigravity-powers-the-system)
3. [The 5 AI Agents](#the-5-ai-agents)
4. [Challenge Requirements Mapping](#challenge-requirements-mapping)
5. [Technical Implementation](#technical-implementation)
6. [Quick Start Guide](#quick-start-guide)
7. [API Documentation](#api-documentation)
8. [Database & Storage](#database--storage)
9. [Deployment](#deployment)
10. [Demo Walkthrough](#demo-walkthrough)
11. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    USER LAYER (Mobile App)                          │
│              Flutter App with Speech Recognition                     │
│          Supports: Urdu, Roman Urdu, English (Real-time)            │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTP/REST
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              ORCHESTRATION LAYER (Google Antigravity)               │
│         Session Management | Workflow Coordination | Trace Logs     │
└────────────────┬──────────────────────────────────┬──────────────────┘
                 │                                  │
        ┌────────▼──────────┐            ┌─────────▼─────────┐
        │   Agent Pipeline   │            │  Database Layer   │
        │                    │            │                   │
        │  1. ZARA: Intent   │────────────│  Firebase         │
        │  2. KHOJI: Search  │────────────│  Firestore        │
        │  3. MUKHTAR: Book  │────────────│  In-Memory DB     │
        │  4. YAKEEN: Remind │────────────│                   │
        │  5. HIFAZAT: Guard │────────────│  External APIs:   │
        │                    │            │  - Google Maps    │
        └────────────────────┘            │  - Gemini LLM     │
                                          │  - Weather API    │
                                          └───────────────────┘
```

### Data Flow
1. **User Input** → Flutter app captures natural language (Urdu/Roman Urdu/English)
2. **ZARA Parsing** → Extracts structured intent (service, location, time, urgency)
3. **KHOJI Discovery** → Searches providers via Google Maps + internal DB
4. **MUKHTAR Booking** → Executes booking with provider & user notifications
5. **YAKEEN Follow-up** → Schedules reminders, ratings, completion checks
6. **HIFAZAT Guardian** → Error recovery if any step fails
7. **Antigravity Trace** → Logs entire workflow for transparency & debugging

---

## 🤖 How Antigravity Powers the System

### Antigravity's Role (Core Platform)
Antigravity is **not just a tool** — it's the **orchestration engine** that makes this system truly agentic.

#### 1. Workflow Orchestration (workflow.yaml)
```yaml
triggers:
  - type: user_message
    input_variable: user_message

workflow:
  - step: initialize_session (generate UUID)
  - step: intent_parsing (ZARA agent)
  - step: check_clarification_needed (conditional routing)
  - step: provider_discovery (KHOJI agent)
  - step: fetch_weather (parallel tool call)
  - step: check_providers_found (conditional routing)
  - step: present_recommendation
  - step: await_user_confirmation (with timeout)
  - step: booking_execution (MUKHTAR agent)
  - step: schedule_followup (YAKEEN agent async)
  - step: compile_trace
  - step: final_response
  
error_routes:
  hifazat: (auto-route to HIFAZAT on failure)
```

**What Antigravity Does:**
- ✅ Manages conditional branching (clarification needed? → ask user → resume)
- ✅ Executes parallel steps (KHOJI search + weather fetch simultaneously)
- ✅ Handles async scheduling (YAKEEN reminders run in background)
- ✅ Implements timeout logic (user confirmation waits 120s, then auto-book if urgent)
- ✅ Routes errors to HIFAZAT guardian automatically
- ✅ Generates execution logs & traces for debugging
- ✅ Maintains session state across multi-step workflow

#### 2. Agent Integration Points
Each agent is called by Antigravity with structured inputs:

```python
# Orchestrator calls agents in sequence
response = await run_orchestration(
    user_message=user_message,
    session_id=session_id,
    platform="flutter",
    client_lat=user_latitude,
    client_lng=user_longitude
)
```

Internally, Antigravity orchestrator:
1. Calls ZARA with user message + chat history
2. Passes ZARA's output to KHOJI (provider search)
3. Routes to MUKHTAR based on KHOJI results
4. Schedules YAKEEN in background via async
5. Monitors entire flow and escalates to HIFAZAT if issues

#### 3. Tool Integration
Antigravity workflows integrate external tools seamlessly:
- **Google Maps API** — Provider location search
- **Firestore** — Booking storage & retrieval
- **Gemini LLM** — Intent parsing & reasoning
- **Weather API** — Context-aware service matching
- **Scheduler** — Reminder scheduling

#### 4. Agentic Decision Making (Critical)
Each agent implements Antigravity's core principle: **Observe → Reason → Decide → Act**

```
ZARA Reasoning Trace:
  "Step 1: Language detected as Roman Urdu (contains 'mujhe', 'kal', 'chahiye')
   Step 2: Service identified as AC_TECHNICIAN (user said 'AC technician chahiye')
   Step 3: Location extracted as G-13, Islamabad (from message + GPS context)
   Step 4: Urgency scored as 7/10 (kal subah = tomorrow morning = medium-high)
   Confidence: 0.92 (high confidence in all extractions)"

KHOJI Reasoning Trace:
  "Distance Score: 2.1km from G-13 → 24/30 points
   Rating Score: 4.8/5 stars → 24/25 points
   Availability Score: Available today → 20/20 points
   Response Rate Score: 94% → 14/15 points
   Verification Score: KHIDMATGAR_VERIFIED → 10/10 points
   TOTAL: 92/100 — Best match for this request"

MUKHTAR Decision Trace:
  "Provider Score: 92/100 (Professional-grade)
   Urgency: 7/10 (high but not critical)
   Decision: CONFIDENCE_AUTO_BOOK (score >= 85 & urgency < 9)
   Reasoning: High-confidence provider with excellent metrics justifies autonomous booking"
```

#### 5. Multi-Step Reasoning Pipeline
Antigravity enables agents to chain reasoning:

```
User: "Mujhe kal subah G-13 mein AC technician chahiye"
            ↓
    [ZARA reads user intent]
            ↓
    {intent: AC_TECH, location: G-13, time: TOMORROW_MORNING, urgency: 7}
            ↓
    [KHOJI searches for providers]
            ↓
    {providers: [Ali AC Services, FastFix Pro, ...], ranking reasoning: ...}
            ↓
    [MUKHTAR books top provider]
            ↓
    {booking_id: KG-20260520-AB12, status: CONFIRMED, eta: 2 hours}
            ↓
    [YAKEEN schedules follow-ups]
            ↓
    {reminders_scheduled: 5, 30, 60, 90 minutes}
            ↓
    [Response sent to user with full trace]
```

---

## 🎭 The 5 AI Agents

### 1️⃣ ZARA — Intent Parser (Observation Phase)

**Role**: Extract structured intent from raw user messages in multiple languages

**Inputs**:
- User message (Urdu, Roman Urdu, or English)
- Chat history (for context understanding)
- GPS coordinates (optional, for location context)

**Processing**:
```python
# Language Detection
Input: "Mujhe kal subah G-13 mein AC technician chahiye"
Detection: ROMAN_URDU (contains "mujhe", "kal", "chahiye" — common Roman Urdu patterns)

# Service Extraction
Service Keywords: ["AC", "technician", "cooling"]
Mapped To: AC_TECHNICIAN (from predefined taxonomy)

# Location Parsing
Raw Input: "G-13 mein"
Extracted: area="G-13", city="Islamabad" (context)
Confidence: 0.95

# Time Understanding
Raw Input: "kal subah"
Mapped To: TOMORROW_MORNING (08:00-12:00)
Urgency: 7/10 (medium-high — next day morning)

# Budget Extraction (if mentioned)
Skipped in this example — none provided
```

**Output** (Structured JSON):
```json
{
  "detected_language": "ROMAN_URDU",
  "service_type": "AC_TECHNICIAN",
  "location": {
    "area": "G-13",
    "city": "Islamabad",
    "confidence": 0.95
  },
  "time_preference": "TOMORROW_MORNING",
  "urgency": {
    "score": 7,
    "reason": "Tomorrow morning = medium-high urgency"
  },
  "clarification_needed": false,
  "reasoning_trace": "Language: Roman Urdu (Urdu script patterns). Service: AC_TECHNICIAN. Location: G-13 (common Islamabad sector). Time: Tomorrow morning. Urgency: 7/10."
}
```

**LLM Used**: Gemini 2.5 Flash (fastest, optimized for NLP)

**Supported Services Taxonomy**:
- AC_TECHNICIAN, ELECTRICIAN, PLUMBER, CARPENTER, PAINTER, CLEANER
- TUTOR, DRIVER, COOK, SECURITY_GUARD, BEAUTY_SERVICES
- PEST_CONTROL, APPLIANCE_REPAIR, MECHANIC, GARDENER, OTHER

**Edge Cases Handled**:
- Ambiguous service (e.g., "ghar ka kaam chahiye") → clarification_needed = true
- Missing location → GPS fallback or ask for clarification
- Informal terminology ("mistri", "wala", "uncle") → normalized to standard terms

---

### 2️⃣ KHOJI — Provider Discovery (Search & Ranking)

**Role**: Find the best service providers using live data and intelligent ranking

**Inputs**:
- Intent JSON from ZARA
- Session ID
- Optional user GPS coordinates

**Search Strategy**:
```
1. Query internal provider database (providers_db.json) for service_type + area
2. Simultaneously search Google Maps Places for "AC Technician near G-13, Islamabad"
3. Merge results, deduplicating by phone number
4. Score each using proprietary algorithm
5. Return top 3 with transparent reasoning
```

**Scoring Algorithm** (Total: 100 points):

| Component | Max Points | Calculation |
|-----------|-----------|-------------|
| Distance | 30 | <1km=30, 1-2km=25, 2-3km=20, 3-5km=15, 5-8km=8, >8km=3 |
| Rating | 25 | (rating / 5) × 25 |
| Availability | 20 | Available now=20, <2hr=15, tomorrow=10, this week=5 |
| Response Rate | 15 | >95%=15, 85-95%=10, 70-85%=6, <70%=2 |
| Verification | 10 | KHIDMATGAR_VERIFIED=10, GOOGLE_VERIFIED=7, unverified=3 |

**Example Output**:
```json
{
  "search_id": "search-uuid",
  "search_summary": {
    "query_service": "AC_TECHNICIAN",
    "query_location": "G-13, Islamabad",
    "search_radius_km": 5,
    "total_found": 12,
    "sources": ["INTERNAL_DB", "GOOGLE_MAPS"],
    "search_duration_ms": 2340
  },
  "providers": [
    {
      "rank": 1,
      "provider_id": "PRV-ISB-001",
      "business_name": "Ali AC & Cooling Services",
      "distance_km": 2.1,
      "eta_minutes": 15,
      "rating": 4.8,
      "review_count": 127,
      "availability": {
        "next_slot": "Today 2PM",
        "is_available_now": true
      },
      "pricing": {
        "visit_fee_pkr": 500,
        "estimated_total_pkr": 2000
      },
      "verification": "KHIDMATGAR_VERIFIED",
      "score": {
        "total": 92,
        "breakdown": {
          "distance": 24,
          "rating": 24,
          "availability": 20,
          "response_rate": 15,
          "verification": 10
        }
      },
      "score_reasoning": "Closest provider with highest rating and immediate availability. KHIDMATGAR verified with 12 years experience."
    },
    {
      "rank": 2,
      "provider_id": "PRV-ISB-002",
      "business_name": "FastFix AC Pro",
      "score": 87,
      "score_reasoning": "Second best: slightly farther (4.5km), but lower price. Excellent response rate (87%)."
    }
  ],
  "recommendation": {
    "recommended_rank": 1,
    "reasoning": "Ali AC Services: Closest (2.1km), highest rating (4.8★), immediate availability, and KHIDMATGAR verified for maximum trust.",
    "alternative_ranks": [2, 3]
  }
}
```

**LLMs & APIs Used**:
- Google Maps Places API (provider location search, real-time data)
- Google Maps Distance Matrix API (ETA calculation)
- Gemini Pro (reasoning about rankings)
- Internal Database (verified providers)

**Anti-Gaming Rules**:
- Never show providers with rating < 3.0 (unless no alternatives)
- Never show providers with >3 unresolved complaints
- If only 1 provider found, flag LIMITED_OPTIONS
- If 0 providers found, trigger HIFAZAT

---

### 3️⃣ MUKHTAR — Booking Engine (Decision & Action)

**Role**: Execute the booking autonomously, generate confirmation, notify all parties

**Booking Decision Logic**:
```
1. Is provider score >= 85?  → PROFESSIONAL_AUTO_BOOK (highest confidence)
2. Is provider score >= 70 & urgency < 9? → CONFIDENCE_AUTO_BOOK
3. Is urgency >= 7? → URGENT_AUTO_BOOK (even with moderate score)
4. Otherwise → STANDARD_AUTO_BOOK

Rule: Never ask user permission for standard bookings (expert autonomous decision)
Exception: CRITICAL urgency (>=8) might require double-confirm slot
```

**Booking Record Creation**:
```python
{
  "booking_id": "KG-20260520-AB12",  # Professional format
  "status": "CONFIRMED",
  "provider": {
    "id": "PRV-ISB-001",
    "name": "Muhammad Ali",
    "rating": 4.8,
    "experience_years": 8
  },
  "service": {
    "type": "AC_TECHNICIAN",
    "slot": "Today 2:00 PM"
  },
  "pricing": {
    "visit_fee_pkr": 500,
    "hourly_rate_pkr": 1500,
    "estimated_total_pkr": 2000
  },
  "location": {
    "area": "G-13",
    "city": "Islamabad",
    "user_coordinates": {"lat": 33.68, "lng": 73.05},
    "provider_coordinates": {"lat": 33.69, "lng": 73.06}
  },
  "decision_reasoning": "Professional-grade provider (score: 92/100) with immediate availability for non-critical service. Autonomous booking justified."
}
```

**Actions Taken**:
1. ✅ Create booking record in Firebase Firestore
2. ✅ Generate booking confirmation (JSON receipt)
3. ✅ Send provider notification via FCM/in-app
4. ✅ Send user confirmation message (multilingual)
5. ✅ Schedule 1-hour reminder
6. ✅ Update provider availability (mark slot as booked)
7. ✅ Log transaction to audit trail

**Confirmation Messages** (Multilingual):

**Roman Urdu**:
```
✅ Booking Confirm! Muhammad Ali aap ke paas kal subah 2 baje 
pahunchenge. Booking ID: KG-20260520-AB12. Aik ghanta pehle 
reminder milega. Cost: PKR 2000. Thank you! 🙏
```

**Urdu**:
```
✅ بکنگ تصدیق ہو گیا! محمد علی آپ کے پاس کل صبح 2 بجے 
پہنچیں گے۔ بکنگ نمبر: KG-20260520-AB12۔ ایک گھنٹہ پہلے 
یاد دہانی ملے گی۔ قیمت: 2000 روپے۔ شکریہ! 🙏
```

**English**:
```
✅ Booking Confirmed! Muhammad Ali will arrive at 2:00 PM today. 
Booking ID: KG-20260520-AB12. Cost: PKR 2000. You'll receive a 
reminder 1 hour before. Thank you! 🙏
```

**Provider Notification**:
```
📋 New Job Alert! 
Customer: G-13, Islamabad
Service: AC Technician repair
Slot: Today 2:00 PM
Estimated Duration: 1-2 hours
Cost: PKR 2000 (visit fee + hourly)
Please confirm within 15 minutes via KhidmatGar App
Job #KG-20260520-AB12
```

**LLM Used**: Gemini Pro (reasoning about autonomous vs. confirmation booking)

---

### 4️⃣ YAKEEN — Follow-up & Accountability

**Role**: Schedule reminders, collect ratings, verify service completion, maintain professional standards

**Reminder Schedule**:
```
+5 min:  "Arrival Reminder" — Provider on the way (courtesy)
+30 min: "Service Progress Check" — Is service proceeding smoothly?
+60 min: "Completion Verification" — Has service been completed?
+90 min: "Quality Rating Request" — Rate your experience (1-5 stars)
```

**For Emergency Services** (urgency >= 8):
```
+20 min: "Urgent Resolution Check" — Special fast-track follow-up
(in addition to standard reminders)
```

**Scheduled Actions JSON**:
```json
{
  "scheduled_actions": [
    {
      "type": "PROFESSIONAL_ARRIVAL_REMINDER",
      "scheduled_at": "2026-05-20T14:05:00Z",
      "message": "Muhammad Ali is on the way to your location",
      "channel": "IN_APP",
      "priority": "HIGH"
    },
    {
      "type": "SERVICE_PROGRESS_CHECK",
      "scheduled_at": "2026-05-20T14:30:00Z",
      "message": "How is the service progressing?",
      "channel": "IN_APP",
      "priority": "MEDIUM"
    },
    {
      "type": "SERVICE_COMPLETION_VERIFICATION",
      "scheduled_at": "2026-05-20T15:00:00Z",
      "message": "Has the service been completed?",
      "provider_id": "PRV-ISB-001",
      "priority": "HIGH"
    },
    {
      "type": "PROFESSIONAL_QUALITY_RATING",
      "scheduled_at": "2026-05-20T15:30:00Z",
      "message": "Rate your experience with Muhammad Ali",
      "provider_id": "PRV-ISB-001",
      "priority": "HIGH"
    }
  ]
}
```

**Rating Collection Flow**:
```
User sees: "⭐ Rate Muhammad Ali's Service"
Options: 1★, 2★, 3★, 4★, 5★ (with optional comment)

If rating >= 4:
  Message: "🌟 Wonderful! Thank you for the great feedback!"
  
If rating < 4:
  Message: "Thank you. HIFAZAT team will review this to improve service."
  
Action: Rating written to provider profile in Firestore
Provider's average rating updated
```

**Follow-up Edge Cases**:
- No-show: Escalate to HIFAZAT after 30-min timeout
- Service extended beyond estimate: Adjust reminders dynamically
- User cancelled: Notify provider, refund initiated
- Provider cancelled: Offer next-best provider from KHOJI list

---

### 5️⃣ HIFAZAT — Guardian & Error Recovery

**Role**: Monitor for failures, handle edge cases, execute graceful fallbacks, ensure system robustness

**Edge Cases & Recovery Strategies**:

#### Scenario 1: No Providers Found
```
Trigger: KHOJI returns 0 providers for AC_TECHNICIAN in G-13
Actions:
  1. Expand search radius (5km → 15km)
  2. Offer next-day scheduling as alternative
  3. Suggest related service categories (e.g., "Appliance Repair")
  4. Message (Roman Urdu): "Maaf kijye, G-13 mein AC technician nahi mila. 
     Kya 15km tak seach karen? Ya kal book kare?"
```

#### Scenario 2: API Timeout
```
Trigger: Google Maps API times out during KHOJI search
Actions:
  1. Fallback to internal provider database
  2. Use cached results (if available)
  3. Message: "Service searching... using offline database. May take longer."
```

#### Scenario 3: Ambiguous Service Intent
```
Trigger: User says "ghar ka kaam chahiye" (house work needed)
ZARA returns: service_type="OTHER", clarification_needed=true
HIFAZAT asks: "Kaunsa kaam? Bijli, pani, safai, carpenter, ya kuch aur?"
```

#### Scenario 4: Model Failure
```
Trigger: Gemini API unavailable
Actions:
  1. Switch to backup lightweight model
  2. Use rule-based intent parsing (keyword matching)
  3. Message: "System temporarily running in lite mode. Some features unavailable."
```

#### Scenario 5: Duplicate Booking Detection
```
Trigger: User tries to book same provider twice within 2 hours
HIFAZAT detects: Booking KG-20260520-AB12 already pending
Actions:
  1. Show existing booking details
  2. Ask: "You already have a booking for this service today. Cancel and re-book?"
```

#### Scenario 6: Emergency at Midnight
```
Trigger: User requests CRITICAL urgency AC repair at 2 AM
Actions:
  1. KHOJI filters providers: accepts_emergency=true, emergency_hours="24/7"
  2. MUKHTAR: Auto-book immediately (skip confirmation)
  3. HIFAZAT: Monitor booking closely, escalate support if needed
```

**Recovery Trace Example**:
```json
{
  "triggered_by": ["NO_PROVIDERS_FOUND"],
  "recovery_actions": [
    {
      "action": "RADIUS_EXPANSION",
      "description": "Searching in 15km radius instead of 5km",
      "status": "ATTEMPTED",
      "result": "Found 3 providers in expanded radius"
    },
    {
      "action": "NEXT_DAY_SCHEDULING",
      "description": "Offering tomorrow's availability",
      "status": "OFFERED"
    }
  ],
  "final_message": "No AC technicians available in G-13 today. Found 3 providers within 15km. Would you like to see them or book for tomorrow?",
  "trace": "HIFAZAT activated: No immediate providers found. Executed radius expansion + next-day options. User presented with alternatives."
}
```

---

## 📊 Challenge Requirements Mapping

### Requirement 1: Understand User Service Requests (Natural Language)

**Challenge Requirement**:
```
Process natural language input in Urdu, Roman Urdu, English
Extract: service type, location, time
```

**How KhidmatGar Fulfills It**:
- ✅ ZARA agent with Gemini 2.5 Flash LLM
- ✅ Detects language automatically (script analysis + keyword patterns)
- ✅ Extracts: service_type, location (area + city), time_preference, urgency
- ✅ Supports Pakistani context (sector names like G-13, F-7, DHA, etc.)
- ✅ Handles informal terminology ("AC wala", "mistri", "plumber uncle")

**Example**:
```
Input: "Mujhe kal subah G-13 mein AC technician chahiye"
ZARA Output: {
  service_type: "AC_TECHNICIAN",
  location: {area: "G-13", city: "Islamabad"},
  time_preference: "TOMORROW_MORNING",
  urgency: 7,
  confidence: 0.92
}
```

---

### Requirement 2: Identify Relevant Providers (Location/Context)

**Challenge Requirement**:
```
Use Google Maps / Places APIs OR mock dataset
Identify nearby providers, service category match
```

**How KhidmatGar Fulfills It**:
- ✅ KHOJI agent with Google Maps Places API integration
- ✅ Internal provider database (providers_db.json) as fallback
- ✅ Haversine distance calculation for accuracy
- ✅ Filters by service_type + location (area + city)
- ✅ Real-time availability checking

**Example Flow**:
```
KHOJI receives: {
  service_type: "AC_TECHNICIAN",
  location: "G-13, Islamabad",
  urgency: 7
}

KHOJI searches:
  1. Internal DB: Find all AC_TECHNICIAN in G-13
  2. Google Maps: Search "AC Technician near G-13, Islamabad"
  3. Calculate distance from user GPS to each provider
  
KHOJI returns: [
  { name: "Ali AC Services", distance: 2.1km, rating: 4.8 },
  { name: "FastFix AC Pro", distance: 4.5km, rating: 4.5 },
  { name: "Expert AC", distance: 6.2km, rating: 4.3 }
]
```

---

### Requirement 3: Select / Recommend Best Provider (Ranking)

**Challenge Requirement**:
```
Rank providers based on:
- distance, availability, rating
Provide clear reasoning for selection
```

**How KhidmatGar Fulfills It**:
- ✅ KHOJI scoring algorithm: Distance(30) + Rating(25) + Availability(20) + ResponseRate(15) + Verification(10) = 100 pts
- ✅ Transparent score breakdown for each provider
- ✅ Reasoning trace: "Why is Ali #1?"
- ✅ Top 3 recommendations shown with clear justification

**Example Output**:
```json
{
  "rank": 1,
  "name": "Ali AC Services",
  "score": 92,
  "breakdown": {
    "distance": 24,        // 2.1km from user
    "rating": 24,          // 4.8 stars
    "availability": 20,    // Available now
    "response_rate": 15,   // 94% response rate
    "verification": 10     // KHIDMATGAR_VERIFIED
  },
  "reasoning": "Best match: Closest (2.1km), highest rating (4.8★ with 127 reviews), 
               immediately available, 8 years experience, and fully verified by KhidmatGar. 
               Recommend booking without hesitation."
}
```

---

### Requirement 4: Booking Simulation (CRITICAL)

**Challenge Requirement**:
```
Simulate booking confirmation, provider assignment, scheduling
Include: updating mock booking system, confirmation message, booking receipt
CRITICAL: Must demonstrate end-to-end booking with clear state change
```

**How KhidmatGar Fulfills It**:
- ✅ MUKHTAR creates booking record (KG-20260520-AB12)
- ✅ Updates Firebase Firestore (state change: PENDING → CONFIRMED)
- ✅ Generates professional booking confirmation
- ✅ Sends provider notification + user confirmation
- ✅ Schedules time slot + reminder
- ✅ Audit trail: All actions logged

**Booking State Transitions**:
```
User: "Book kar do"
  ↓
MUKHTAR: Create booking record
  Status: PENDING
  ↓
Provider notified, MUKHTAR awaits confirmation
  ↓
Provider accepts: Status → CONFIRMED
  ↓
1-hour pre-appointment: Reminder sent
  ↓
Service completion: Status → COMPLETED
  ↓
Rating collected: Status → RATED
```

**Confirmation Record**:
```json
{
  "booking_id": "KG-20260520-AB12",
  "timestamp": "2026-05-20T14:00:00Z",
  "user": {
    "name": "User",
    "location": "G-13, Islamabad"
  },
  "provider": {
    "name": "Muhammad Ali",
    "business": "Ali AC & Cooling Services",
    "rating": 4.8,
    "phone": "+92-3XX-XXXXXXX"
  },
  "service": {
    "type": "AC_TECHNICIAN",
    "description": "AC repair",
    "slot": "Today 2:00 PM"
  },
  "pricing": {
    "visit_fee": 500,
    "hourly_rate": 1500,
    "estimated_total": 2000,
    "currency": "PKR"
  },
  "status": "CONFIRMED",
  "confirmation_message": "Booking confirmed! Muhammad Ali will arrive by 2:30 PM.",
  "reminder_scheduled": "2026-05-20T13:00:00Z"
}
```

---

### Requirement 5: Follow-Up Automation

**Challenge Requirement**:
```
Simulate: reminders, status updates, completion confirmation
```

**How KhidmatGar Fulfills It**:
- ✅ YAKEEN schedules 4 reminders: +5min, +30min, +60min, +90min
- ✅ Progress check-ins: "Service proceeding smoothly?"
- ✅ Completion verification: "Has service been completed?"
- ✅ Quality feedback: "Rate your experience (1-5 stars)"
- ✅ Professional accountability: Provider performance tracked

**Follow-up Timeline**:
```
14:00 Booking Confirmed
14:05 → "Arrival Reminder: Provider on the way" (IN_APP notification)
14:30 → "How is service progressing?" (PROGRESS_CHECK)
15:00 → "Has service completed?" (COMPLETION_VERIFY)
15:30 → "Rate Muhammad Ali's service" (QUALITY_RATING)

If user rates 5 stars:
  → "🌟 Thank you for the amazing feedback!"
  → Rating added to provider profile
  → Provider's average updated
  
If user rates < 4 stars:
  → "Thank you for feedback. HIFAZAT team will review."
  → Escalation triggered for quality assurance
```

---

### Requirement 6: Agentic Workflow (MANDATORY)

**Challenge Requirement**:
```
Demonstrate multi-step agentic reasoning
Flow: planning → decision → action → follow-up
Show traceable logs of decisions, tool usage, action execution
```

**How KhidmatGar Fulfills It**:
- ✅ 5-Agent Pipeline with clear responsibilities
- ✅ Multi-step reasoning: ZARA → KHOJI → MUKHTAR → YAKEEN → HIFAZAT
- ✅ Each agent observes, reasons, decides, acts
- ✅ Full trace logs for every step
- ✅ Error recovery via HIFAZAT guardian

**Agentic Trace Log**:
```
Session: sess-uuid-1234
Timestamp: 2026-05-20T14:00:00Z
User Message: "Mujhe kal subah G-13 mein AC technician chahiye"

========== STEP 1: ZARA INTENT PARSING ==========
Agent: ZARA
Input: user_message, chat_history
Processing Time: 340ms
Output: {
  service_type: "AC_TECHNICIAN",
  location: {area: "G-13", city: "Islamabad"},
  time_preference: "TOMORROW_MORNING",
  urgency: 7,
  confidence: 0.92
}
Reasoning Trace:
  "1. Language: Detected ROMAN_URDU from 'mujhe', 'kal', 'chahiye'
   2. Service: 'AC technician' maps to AC_TECHNICIAN category
   3. Location: 'G-13' is Islamabad sector, confidence 0.95
   4. Time: 'kal subah' = tomorrow morning, urgency 7/10
   5. Decision: No clarification needed, proceed to KHOJI"

========== STEP 2: KHOJI PROVIDER DISCOVERY ==========
Agent: KHOJI
Input: intent_json, session_id
Processing Time: 2340ms
Output: {
  total_found: 12,
  providers: [
    {rank: 1, name: "Ali AC Services", score: 92, reasoning: "..."},
    {rank: 2, name: "FastFix AC Pro", score: 87, reasoning: "..."},
    {rank: 3, name: "Expert AC", score: 79, reasoning: "..."}
  ]
}
Reasoning Trace:
  "1. Searched internal DB: Found 8 AC technicians in G-13
   2. Searched Google Maps: Found 4 additional providers in 5km radius
   3. Scored all 12 using algorithm: Distance(30) + Rating(25) + Availability(20) + ResponseRate(15) + Verification(10)
   4. Ali: 24+24+20+15+10 = 92/100 (best match)
   5. Recommendation: Book Ali AC Services"

========== STEP 3: MUKHTAR BOOKING EXECUTION ==========
Agent: MUKHTAR
Input: top_provider, intent, session_id
Processing Time: 1200ms
Output: {
  booking_id: "KG-20260520-AB12",
  status: "CONFIRMED",
  booking_mode: "CONFIDENCE_AUTO_BOOK"
}
Reasoning Trace:
  "1. Observe: Provider score 92/100 (professional grade)
   2. Observe: Urgency 7/10 (high but not critical)
   3. Reason: Score >= 85 & urgency < 9 = autonomous booking justified
   4. Decide: CONFIDENCE_AUTO_BOOK (no user confirmation needed)
   5. Act: Create booking record KG-20260520-AB12
   6. Act: Notify provider via FCM
   7. Act: Send user confirmation (multilingual)
   8. Act: Schedule reminders"

Actions Executed:
  ✅ Booking created in Firebase
  ✅ Provider notified: "New Job Alert! KG-20260520-AB12"
  ✅ User confirmed: Multilingual confirmation sent
  ✅ Reminder scheduled: +60 minutes

========== STEP 4: YAKEEN FOLLOW-UP SCHEDULING ==========
Agent: YAKEEN
Input: booking, intent
Processing Time: 450ms
Output: {
  scheduled_actions: [
    {type: "ARRIVAL_REMINDER", at: "+5min"},
    {type: "PROGRESS_CHECK", at: "+30min"},
    {type: "COMPLETION_VERIFY", at: "+60min"},
    {type: "QUALITY_RATING", at: "+90min"}
  ]
}

========== STEP 5: HIFAZAT STANDBY ==========
Agent: HIFAZAT
Status: ON_STANDBY
Message: "No errors detected. All systems green."

========== FULL TRACE SUMMARY ==========
Workflow Status: ✅ COMPLETED SUCCESSFULLY
Total Processing Time: 4.33 seconds
Agents Activated: ZARA → KHOJI → MUKHTAR → YAKEEN
Error Recovery: None needed
Final State: Booking confirmed, reminders scheduled
User Notification: ✅ Sent (Roman Urdu)
```

---

### Requirement 7: Google Antigravity (MANDATORY)

**Challenge Requirement**:
```
Use Google Antigravity as CORE platform to:
- Orchestrate agent workflows
- Manage multi-step reasoning
- Integrate tools (Maps, Search, APIs)
- Execute actions (booking, notifications, etc.)
```

**How KhidmatGar Uses Antigravity**:

#### Workflow Definition (workflow.yaml)
```yaml
# Antigravity orchestrates entire flow
triggers:
  - type: user_message

workflow:
  - step: initialize_session        # Create session
  - step: intent_parsing [ZARA]     # Parse intent
  - step: check_clarification_needed # Conditional branching
  - step: provider_discovery [KHOJI]# Search providers
  - step: fetch_weather [parallel]  # Parallel tool call
  - step: booking_execution [MUKHTAR] # Book provider
  - step: schedule_followup [YAKEEN] # Schedule reminders [async]
  - step: compile_trace             # Aggregate logs
  - step: final_response            # Return to user

error_routes:
  - route: HIFAZAT                  # Auto-escalate to guardian
```

#### Agent Invocation via Antigravity
```python
# Backend orchestrator.py
async def run_orchestration(user_message, session_id, ...):
    # Antigravity manages these steps:
    
    # 1. Initialize session
    workplan = {steps: [...]}
    
    # 2. Call ZARA (Antigravity handles I/O)
    zara_result = get_zara_intent(user_message, ...)
    
    # 3. Conditional logic (Antigravity evaluates)
    if zara_result.get("clarification_needed"):
        return clarification_message  # Pause, await user response
    
    # 4. Provider discovery (KHOJI)
    khoji_result = get_khoji_providers(zara_result, ...)
    
    # 5. Booking execution (MUKHTAR)
    mukhtar_result = run_mukhtar_booking(top_provider, ...)
    
    # 6. Follow-up scheduling (YAKEEN async)
    yakeen_result = run_yakeen_followup(booking, ...)  # Non-blocking
    
    # 7. Error handling (HIFAZAT)
    if error_detected:
        hifazat_result = run_hifazat_guard(error, ...)
    
    # 8. Compile trace
    trace = compile_agent_trace(zara, khoji, mukhtar, yakeen, hifazat)
    
    # 9. Return response
    return _build_response(session_id, final_message, booking, trace, ...)
```

#### Tool Integration via Antigravity
```
Antigravity handles these external tool calls:
✅ Google Maps Places API → KHOJI provider search
✅ Google Maps Distance Matrix → ETA calculation
✅ Firebase Firestore → Booking storage
✅ Firebase FCM → Provider notifications
✅ Gemini LLM → Intent parsing & reasoning
✅ Scheduler API → Reminder scheduling
✅ Weather API → Service context (rain, heat, etc.)
```

#### Agentic Properties
```
✓ Autonomy: Each agent makes decisions independently
✓ Reasoning: Each agent shows step-by-step reasoning trace
✓ Collaboration: Agents share outputs via Antigravity orchestrator
✓ Error Recovery: HIFAZAT handles failures
✓ Multi-step: Planning → Decision → Action → Evaluation
✓ Transparency: Full trace logs for every step
✓ Scalability: Async scheduling via Antigravity
```

---

## 🛠️ Technical Implementation

### Backend Architecture

**Framework**: FastAPI (Python)
**Database**: Firebase Firestore + In-Memory Store
**LLM**: Google Gemini 2.5 Flash & Gemini Pro
**APIs**: Google Maps, Google Places, Weather API
**Deployment**: Render.com

**File Structure**:
```
backend/
├── main.py                    # FastAPI app + endpoints
├── orchestrator.py            # Antigravity orchestration logic
├── agents/
│   ├── zara_agent.py         # Intent parser
│   ├── khoji_agent.py        # Provider discovery
│   ├── mukhtar_agent.py      # Booking engine
│   ├── yakeen_agent.py       # Follow-up scheduler
│   └── hifazat_agent.py      # Error recovery
├── data/
│   └── providers_db.json     # Mock provider database
├── firebase_credentials.json  # Firebase config
├── requirements.txt          # Python dependencies
└── web/                       # Static UI (optional)
```

### Frontend Architecture

**Framework**: Flutter 3.10+ (Dart)
**State Management**: Riverpod
**Authentication**: Firebase Auth + Google Sign-In
**Notifications**: Flutter Local Notifications
**Maps**: Google Maps Flutter
**Backend Communication**: HTTP + Dio

**File Structure**:
```
khidmatgar/
├── lib/
│   ├── main.dart             # App entry point
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── role_selection_screen.dart
│   │   ├── home_screen.dart  # Main chat interface
│   │   ├── chat_screen.dart  # Service request input
│   │   ├── map_view_screen.dart
│   │   ├── booking_history_screen.dart
│   │   ├── provider_profile_screen.dart
│   │   └── ...
│   ├── services/
│   │   ├── antigravity_service.dart # Backend communication
│   │   └── notification_service.dart
│   ├── providers/              # Riverpod state management
│   ├── models/                 # Data models
│   ├── theme/
│   │   └── app_theme.dart     # Dark theme
│   └── widgets/                # Reusable UI components
├── pubspec.yaml               # Flutter dependencies
├── android/                    # Android config
└── ios/                        # iOS config
```

### Database Schema

**Firebase Firestore Collections**:

**users/**
```json
{
  "uid": "firebase-uid",
  "name": "User Name",
  "phone": "+92-3XX-XXXXXXX",
  "language_preference": "ROMAN_URDU",
  "location": {"lat": 33.68, "lng": 73.05},
  "created_at": "2026-05-20T10:00:00Z"
}
```

**bookings/**
```json
{
  "booking_id": "KG-20260520-AB12",
  "session_id": "sess-uuid",
  "user_id": "uid",
  "provider_id": "PRV-ISB-001",
  "service_type": "AC_TECHNICIAN",
  "status": "CONFIRMED",
  "slot": "2026-05-20T14:00:00Z",
  "pricing": {...},
  "created_at": "2026-05-20T13:00:00Z"
}
```

**providers/**
```json
{
  "provider_id": "PRV-ISB-001",
  "name": "Muhammad Ali",
  "business_name": "Ali AC & Cooling Services",
  "phone": "+92-300-1234567",
  "service_categories": ["AC_TECHNICIAN", "APPLIANCE_REPAIR"],
  "rating": 4.8,
  "review_count": 127,
  "coordinates": {"lat": 33.69, "lng": 73.06},
  "verification": "KHIDMATGAR_VERIFIED"
}
```

---

## 🚀 Quick Start Guide

### Prerequisites
- Python 3.9+ (for backend)
- Flutter 3.10+ (for mobile)
- Google Cloud API keys (Maps, Gemini)
- Firebase project setup

### Backend Setup

```bash
# 1. Clone repository
cd backend

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Create .env file
cat > .env << EOF
GEMINI_API_KEY=your-google-gemini-api-key
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
WEATHER_API_KEY=your-weather-api-key (optional)
EOF

# 5. Copy Firebase credentials
cp /path/to/firebase_credentials.json .

# 6. Run backend
uvicorn main:app --reload

# API docs: http://localhost:8000/docs
```

### Flutter App Setup

```bash
# 1. Navigate to Flutter project
cd khidmatgar

# 2. Get dependencies
flutter pub get

# 3. Configure Firebase
# Copy google-services.json to:
# - khidmatgar/ (root)
# - khidmatgar/android/app/

# 4. Run app
flutter run

# 5. Build APK
flutter build apk --release
```

### Environment Variables

**Backend (.env)**:
```
GEMINI_API_KEY=AIzaSy...
GOOGLE_MAPS_API_KEY=AIzaSy...
FIREBASE_PROJECT_ID=khidmatgar-40f9a
FIREBASE_PRIVATE_KEY=-----BEGIN RSA PRIVATE KEY-----\n...
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@khidmatgar.iam.gserviceaccount.com
```

**Firebase (google-services.json)**:
```json
{
  "project_id": "khidmatgar-40f9a",
  "private_key_id": "...",
  "private_key": "...",
  "client_email": "...",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "...",
  "client_x509_cert_url": "..."
}
```

---

## 📡 API Documentation

### Health Check

```http
GET /health
```

**Response**:
```json
{
  "status": "healthy",
  "service": "KhidmatGar Antigravity Backend",
  "version": "2.0.0",
  "agents": ["ZARA", "KHOJI", "MUKHTAR", "YAKEEN", "HIFAZAT"],
  "timestamp": "2026-05-20T14:00:00Z",
  "env": {
    "gemini_configured": true,
    "maps_configured": true
  }
}
```

### Main Orchestration Endpoint

```http
POST /v1/workflows/khidmatgar-master/run
Content-Type: application/json

{
  "inputs": {
    "user_message": "Mujhe kal subah G-13 mein AC technician chahiye",
    "platform": "flutter",
    "client_lat": 33.6844,
    "client_lng": 73.0479,
    "session_id": "sess-uuid-optional"
  },
  "stream": false
}
```

**Response**:
```json
{
  "session_id": "sess-uuid",
  "final_message": "✅ Booking confirmed with Muhammad Ali! Estimated cost: PKR 2000.",
  "status": "SUCCESS",
  "workflow_trace": {
    "agents_executed": ["ZARA", "KHOJI", "MUKHTAR", "YAKEEN"],
    "total_time_ms": 4330,
    "steps_completed": 9
  },
  "booking": {
    "booking_id": "KG-20260520-AB12",
    "provider": "Muhammad Ali",
    "slot": "Today 2:00 PM",
    "pricing": 2000
  },
  "providers": [
    {
      "rank": 1,
      "name": "Ali AC Services",
      "score": 92,
      "distance": 2.1,
      "eta": 15
    },
    {
      "rank": 2,
      "name": "FastFix AC Pro",
      "score": 87,
      "distance": 4.5,
      "eta": 25
    }
  ],
  "agent_traces": {
    "zara": {...},
    "khoji": {...},
    "mukhtar": {...},
    "yakeen": {...}
  }
}
```

### Booking Confirmation

```http
POST /v1/booking/confirm
Content-Type: application/json

{
  "booking_id": "KG-20260520-AB12",
  "session_id": "sess-uuid",
  "rating": 5,
  "feedback": "Excellent service!"
}
```

---

## 🔥 Firebase Setup

### Step 1: Create Firebase Project
1. Go to [firebase.google.com](https://firebase.google.com)
2. Create new project → "khidmatgar"
3. Enable Firestore Database
4. Enable Authentication (Google Sign-In)

### Step 2: Download Credentials
1. Project Settings → Service Accounts
2. Generate new private key → Save as `firebase_credentials.json`
3. Copy `google-services.json` from project

### Step 3: Configure in Backend
```bash
cp firebase_credentials.json backend/
```

### Step 4: Configure in Flutter
```bash
cp google-services.json khidmatgar/
cp google-services.json khidmatgar/android/app/
```

---

## 🚢 Deployment

### Backend Deployment (Render.com - Free)

```bash
# 1. Push to GitHub
git push origin main

# 2. Go to render.com
# → New → Web Service
# → Connect GitHub repository

# 3. Configure:
# Name: khidmatgar-backend
# Root Directory: backend
# Build Command: pip install -r requirements.txt
# Start Command: uvicorn main:app --host 0.0.0.0 --port $PORT
# Environment Variables:
#   GEMINI_API_KEY=...
#   GOOGLE_MAPS_API_KEY=...

# 4. Deploy
# → Your API available at: https://khidmatgar-backend.onrender.com
```

### Frontend Deployment (Google Play)

```bash
# 1. Build release APK
cd khidmatgar
flutter build apk --release

# 2. Sign APK
# Use Android Studio or command line signing

# 3. Upload to Google Play Console
# → Internal Testing → Upload APK
# → Release to production

# 4. Share link: https://play.google.com/store/apps/details?id=com.khidmatgar.app
```

### Live Services
- **Backend API**: https://khidmatgar-backend.onrender.com
- **API Docs**: https://khidmatgar-backend.onrender.com/docs
- **Health Check**: https://khidmatgar-backend.onrender.com/health

---

## 🎬 Demo Walkthrough

### Scenario: AC Repair Emergency

**Step 1: User Sends Request**
```
User (speaking in Urdu): "Mujhe kal subah G-13 mein AC technician chahiye"
(Translation: "I need an AC technician in G-13 tomorrow morning")

App captures voice → Converts to text
```

**Step 2: ZARA Parses Intent**
```
Input: "Mujhe kal subah G-13 mein AC technician chahiye"
Detected Language: ROMAN_URDU
Service Extracted: AC_TECHNICIAN
Location: G-13, Islamabad
Time: TOMORROW_MORNING
Urgency: 7/10
Confidence: 92%
```

**Step 3: KHOJI Discovers Providers**
```
Search Query: "AC Technician near G-13, Islamabad"
Sources: Google Maps + Internal DB
Found: 12 providers in 5km radius

Top Results:
1. Ali AC Services — 2.1km away — 4.8★ (127 reviews) — Score: 92/100
2. FastFix AC Pro — 4.5km away — 4.5★ (89 reviews) — Score: 87/100
3. Expert AC — 6.2km away — 4.3★ (45 reviews) — Score: 79/100
```

**Step 4: MUKHTAR Books Top Provider**
```
Decision: CONFIDENCE_AUTO_BOOK (score 92 >= 85)
Action: Create Booking KG-20260520-AB12
Status: CONFIRMED
Slot: Today 2:00 PM
Cost: PKR 2000
Provider: Muhammad Ali
Phone: +92-300-1234567 (masked)
```

**Step 5: YAKEEN Schedules Follow-ups**
```
+5 min:  "Provider on the way"
+30 min: "Service progress check"
+60 min: "Service completion?"
+90 min: "Rate your experience" ⭐⭐⭐⭐⭐
```

**Step 6: User Receives Confirmation (Multilingual)**
```
Roman Urdu:
"✅ Booking Confirm! Muhammad Ali aap ke paas kal subah 2 baje 
pahunchenge. Booking ID: KG-20260520-AB12. Aik ghanta pehle reminder 
milega. Cost: PKR 2000. Shukriya! 🙏"

English:
"✅ Booking Confirmed! Muhammad Ali will arrive at 2:00 PM. 
Booking ID: KG-20260520-AB12. Cost: PKR 2000. You'll receive a 
reminder 1 hour before. Thank you! 🙏"
```

**Step 7: Provider Receives Notification**
```
📋 New Job Alert!
Customer: G-13, Islamabad
Service: AC Technician repair
Slot: Today 2:00 PM
Estimated Duration: 1-2 hours
Cost: PKR 2000 (visit fee + hourly)
Confirm in app: Job #KG-20260520-AB12
```

**Step 8: Reminders & Follow-up**
```
2:00 PM: Booking confirmed
2:05 PM: "Provider on the way"
2:30 PM: "How's the service going?"
3:00 PM: "Completed?"
3:30 PM: "Rate your experience: ⭐⭐⭐⭐⭐"

User rates 5 stars:
Response: "🌟 Thank you for the amazing feedback!"
```

---

## 🐛 Troubleshooting

### Backend Won't Start
```bash
# Check Python version
python --version  # Should be 3.9+

# Check dependencies
pip install -r requirements.txt

# Check environment variables
echo $GEMINI_API_KEY

# Check port
lsof -i :8000  # See if port 8000 is in use
```

### API Returns 400: Missing Inputs
```json
{
  "detail": "user_message is required and cannot be empty"
}
```

**Fix**: Ensure request body includes:
```json
{
  "inputs": {
    "user_message": "your message here"
  }
}
```

### Firebase Connection Error
```
firebase_admin.exceptions.DefaultCredentialsError: credentials not available
```

**Fix**:
```bash
# Ensure firebase_credentials.json exists in backend/
cp /path/to/credentials.json backend/firebase_credentials.json

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=backend/firebase_credentials.json
```

### Gemini API Error
```
google.api_core.exceptions.PermissionDenied: API key not valid
```

**Fix**:
```bash
# Get valid API key from Google Cloud Console
# Set in .env
GEMINI_API_KEY=AIzaSy...

# Verify
curl -H "Authorization: Bearer $GEMINI_API_KEY" https://generativelanguage.googleapis.com/v1/models/gemini-pro
```

### Google Maps API Not Working
```
"Status: REQUEST_DENIED" from Google Maps Places API
```

**Fix**:
```bash
# Verify API key has Maps & Places enabled
# Google Cloud Console → APIs & Services → Libraries
# Enable: Maps SDK, Places API, Distance Matrix API

# Check API key restrictions (shouldn't restrict to specific IPs)
```

### Flutter App Won't Connect to Backend
```
SocketException: OS Error: Connection refused, errno = 111
```

**Fix**:
```bash
# Ensure backend is running
curl http://localhost:8000/health

# Update backend URL in Flutter app
# File: lib/services/antigravity_service.dart
const String backendUrl = "https://khidmatgar-backend.onrender.com";
```

### Firebase Auth Not Working in Flutter
```
PlatformException: SIGN_IN_CANCELLED, User cancelled sign-in
```

**Fix**:
```bash
# Ensure google-services.json is in correct locations:
# - khidmatgar/
# - khidmatgar/android/app/

# Rebuild app
flutter clean
flutter pub get
flutter build apk
```

---

## 📁 Project Files

### Important Files to Review

1. **Agent Implementations**:
   - [backend/agents/zara_agent.py](backend/agents/zara_agent.py) — Intent parsing
   - [backend/agents/khoji_agent.py](backend/agents/khoji_agent.py) — Provider discovery
   - [backend/agents/mukhtar_agent.py](backend/agents/mukhtar_agent.py) — Booking engine
   - [backend/agents/yakeen_agent.py](backend/agents/yakeen_agent.py) — Follow-ups
   - [backend/agents/hifazat_agent.py](backend/agents/hifazat_agent.py) — Error recovery

2. **Orchestration**:
   - [backend/orchestrator.py](backend/orchestrator.py) — Main workflow logic
   - [khidmatgar/antigravity/workflow.yaml](khidmatgar/antigravity/workflow.yaml) — Antigravity workflow definition

3. **Backend API**:
   - [backend/main.py](backend/main.py) — FastAPI endpoints

4. **Flutter App**:
   - [khidmatgar/lib/main.dart](khidmatgar/lib/main.dart) — App entry point
   - [khidmatgar/lib/screens/home_screen.dart](khidmatgar/lib/screens/home_screen.dart) — Main UI
   - [khidmatgar/lib/services/antigravity_service.dart](khidmatgar/lib/services/antigravity_service.dart) — Backend communication

5. **Data**:
   - [backend/data/providers_db.json](backend/data/providers_db.json) — Mock provider database

---

## 📝 License & Credits

**Project**: KhidmatGar (#AISeekho 2026)
**Challenge**: Challenge 2: AI Service Orchestrator for Informal Economy
**Hackathon**: Google Antigravity Hackathon
**Partners**: Google for Developers, Telenor Pakistan, Ministry of IT & Telecom

---

## 🤝 Contact & Support

For issues or questions:
- Check Troubleshooting section above
- Review agent documentation in `khidmatgar/antigravity/`
- Test API endpoints with Swagger UI: `/docs`
- Check backend logs: `python main.py --reload`

---

**Built with ❤️ for Pakistan's Informal Economy**

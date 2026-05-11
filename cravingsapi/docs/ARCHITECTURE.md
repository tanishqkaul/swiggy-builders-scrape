# Architecture — CravingsAPI

## System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                                  │
│                                                                       │
│   ┌───────────────────┐          ┌────────────────────┐             │
│   │  React Native App │          │  Web Dashboard     │             │
│   │  (iOS + Android)  │          │  (Next.js / Vercel)│             │
│   └────────┬──────────┘          └──────────┬─────────┘             │
└────────────┼───────────────────────────────┼───────────────────────┘
             │ HTTPS / REST + WebSocket       │ HTTPS
             ▼                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        API GATEWAY (FastAPI)                         │
│                        Railway — Python 3.12                         │
│                                                                       │
│   /auth/*   /users/*   /predictions/*   /orders/*   /signals/*      │
└──────┬────────────┬───────────────┬──────────────────┬──────────────┘
       │            │               │                  │
       ▼            ▼               ▼                  ▼
┌──────────┐ ┌──────────┐ ┌────────────────┐ ┌──────────────────┐
│  Auth    │ │  User    │ │  Prediction    │ │  Order           │
│  Service │ │  Service │ │  Engine        │ │  Orchestrator    │
│          │ │          │ │  (ML Core)     │ │                  │
│ Supabase │ │ Postgres │ │ ONNX Runtime   │ │  Swiggy MCP      │
│ Auth     │ │ + Redis  │ │ + Feature Eng  │ │  Client          │
└──────────┘ └──────────┘ └────────────────┘ └──────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
           ┌──────────────┐       ┌──────────────────┐
           │  Signal      │       │  Notification    │
           │  Aggregator  │       │  Scheduler       │
           │              │       │                  │
           │ - Weather API│       │ Firebase FCM     │
           │ - Sahha.ai   │◄──────│ + Redis queues   │
           │ - Time/Day   │       └──────────────────┘
           │ - Cycle Svc  │
           └──────┬───────┘
                  │
           ┌──────▼───────┐
           │  Cycle       │
           │  Service     │
           │              │
           │ - Phase det  │
           │ - Sahha conf │
           │ - Period log │
           └──────────────┘
```

---

## Service Breakdown

### 1. API Gateway (`/src/api/`)
**Runtime:** FastAPI + Uvicorn, Python 3.12
**Responsibility:** Route all incoming requests, authenticate JWT, rate-limit, validate payloads, dispatch to internal services.
**Talks to:** All internal services via direct Python function calls (monorepo). External callers get REST.

### 2. Auth Service (`/src/services/auth/`)
**Responsibility:** OAuth2 flow with Swiggy MCP, issue/refresh JWT sessions, manage Swiggy access token refresh cycle.
**Storage:** Supabase Auth (user identity) + PostgreSQL (swiggy token store, encrypted).
**Key flows:**
- `POST /auth/swiggy/callback` — exchange Swiggy OAuth code for tokens, upsert user
- `POST /auth/refresh` — rotate JWT + Swiggy token atomically
- `DELETE /auth/session` — full logout + token revocation

### 3. User Service (`/src/services/users/`)
**Responsibility:** User profile, preferences, dietary flags, timezone, connected health apps.
**Storage:** PostgreSQL `users` table + `user_preferences` table.
**Key operations:** CRUD preferences, read aggregated signal history for a user.

### 4. Signal Aggregator (`/src/services/signals/`)
**Responsibility:** Pull and normalize all behavioral signals for a user at a given point in time.
**Sources:**
- Swiggy MCP (order history, last 180 days)
- OpenWeatherMap (current conditions + 3h forecast at user location)
- **Sahha.ai REST API** (processed biomarkers: HRV, resting HR, sleep score, readiness, mental wellbeing — replaces raw HealthKit/Fit)
- **Cycle Service** (current phase, cycle day, days until period, Sahha phase confirmation)
- Computed: time-of-day bucket, day-of-week, days-since-last-order, streak data
**Output:** A 95-dim feature vector fed into the prediction engine.
**Schedule:** Runs every 15 minutes per active user via Redis-backed job queue.

### 4B. Cycle Service (`/src/services/cycle/`)
**Responsibility:** Manage menstrual cycle tracking data — compute current phase, confirm phase against Sahha biomarkers, handle period logging, send reminder notifications.
**Storage:** `cycle_profiles`, `cycle_period_log` tables (column-level encrypted).
**Key operations:**
- `get_current_phase(user_id)` → CyclePhase with day, phase name, days until next period
- `confirm_phase_with_sahha(phase, sahha_biomarkers)` → phase_confidence_multiplier
- `log_period_start(user_id, date)` → upsert cycle_profiles, append cycle_period_log
- `maybe_suggest_period_start(user_id, sahha_signals)` → triggers nudge if biomarkers pattern matches period onset
**Privacy:** All DB reads to this service are logged to `cycle_data_access_log`.

### 5. Prediction Engine (`/src/ml/`)
**Responsibility:** Given a feature vector, output (item_id, confidence, eta_minutes) — the predicted craving with its confidence score and the optimal notification delivery window.
**Model:** Gradient Boosted Trees (XGBoost) → exported to ONNX for fast inference. No GPU needed.
**Training:** Offline, weekly retrain on anonymized order corpus. Training scripts in `/ml/training/`.
**Inference:** ONNX Runtime in-process, p50 < 8ms per prediction.
**Fallback:** Rule-based heuristic (most-ordered item at this hour on this weekday) when model confidence < 0.35.

### 6. Notification Scheduler (`/src/services/notifications/`)
**Responsibility:** Decide *when* to fire a push notification, build the payload, schedule via FCM, track open/dismiss/order events.
**Logic:**
- Runs after prediction: if confidence ≥ threshold (0.55 default, tunable per user) → compute optimal fire time (30–90 min before predicted craving window) → enqueue FCM job
- Respects user quiet hours (22:00–07:00 default, configurable)
- Max 2 notifications per day per user
- Tracks CTR and order-through rate for per-user threshold adaptation

### 7. Order Orchestrator (`/src/services/orders/`)
**Responsibility:** Pre-build a Swiggy cart from the prediction, place order on user tap, track status.
**Talks to:** Swiggy MCP Food/Instamart endpoints.
**Cart pre-build:** On notification schedule → call Swiggy MCP to verify item availability + pricing → store pre-built cart ID with 90-min TTL in Redis.
**One-tap flow:** User taps notification → app fetches pre-built cart → shows confirm screen (5s countdown) → places order via Swiggy MCP.

---

## Data Flow: End-to-End Prediction Cycle

```
[Redis Scheduler — every 15min]
        │
        ▼
Signal Aggregator.collect(user_id)
        │
        ├── Swiggy MCP: GET /orders/history?days=180
        ├── OpenWeatherMap: GET /weather?lat=&lon=
        └── HealthKit/Fit REST (if connected)
        │
        ▼
Feature Engineering (normalize, encode, compute deltas)
        │
        ▼
Prediction Engine.infer(feature_vector)
  → { item_id: "biryani_xyz", confidence: 0.72, window: "19:30–20:30" }
        │
        ▼ (if confidence ≥ threshold)
Notification Scheduler.schedule(user_id, prediction)
  → computes fire_time = window.start - 45min
  → pre-builds Swiggy cart → stores cart_id in Redis (TTL 90min)
  → enqueues FCM message for fire_time
        │
        ▼ (at fire_time)
FCM push → user device
        │
        ▼ (user taps)
Order Orchestrator.confirm(user_id, cart_id)
  → show confirm screen
  → on confirm: Swiggy MCP POST /orders/place
```

---

## Infrastructure

| Component | Provider | Tier |
|---|---|---|
| API server | Railway | Starter ($5/mo) |
| PostgreSQL | Supabase | Free → Pro |
| Redis | Upstash | Pay-per-request |
| ML model hosting | Railway (same pod) | — |
| Push notifications | Firebase FCM | Free |
| Mobile builds | Expo EAS | Free tier |
| Web dashboard | Vercel | Free |
| Monitoring | Sentry + Grafana Cloud | Free tier |

---

## Scalability Path

- **Phase 1 (hackathon):** Monolith FastAPI, single Railway instance, Supabase free.
- **Phase 2 (100 users):** Extract signal aggregator to a background worker, add Redis job queues (BullMQ-equivalent via rq).
- **Phase 3 (10K users):** Horizontally scale API, move ML inference to a dedicated inference pod, add read replicas.
- **Phase 4 (100K users):** Kafka for signal stream, separate ML training cluster, CDN for static assets.

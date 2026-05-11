# Implementation Map — CravingsAPI

> Every file in the codebase, its single responsibility, and how it connects to others.

---

## Repository Structure

```
cravingsapi/
├── apps/
│   ├── mobile/                  # React Native + Expo app
│   └── web/                     # Next.js admin/user dashboard
├── services/
│   └── api/                     # FastAPI backend (Python)
├── ml/
│   ├── training/                # Offline training scripts
│   ├── models/                  # Saved ONNX model artifacts
│   └── inference/               # Runtime inference wrapper
├── shared/
│   ├── types/                   # Shared TypeScript types (mobile/web)
│   └── constants/               # Shared constants
├── infra/
│   ├── docker/                  # Dockerfiles
│   └── railway/                 # railway.toml configs
└── docs/                        # This folder
```

---

## `apps/mobile/` — React Native App

```
apps/mobile/
├── app/
│   ├── _layout.tsx              # Root navigator, auth gate
│   ├── index.tsx                # Splash/redirect
│   ├── (auth)/
│   │   ├── login.tsx            # Swiggy OAuth login screen
│   │   └── onboarding/
│   │       ├── step-1-location.tsx   # Location permission
│   │       ├── step-2-health.tsx     # HealthKit/Fit opt-in
│   │       └── step-3-prefs.tsx      # Dietary preferences
│   ├── (app)/
│   │   ├── home.tsx             # Main dashboard — recent predictions, streak
│   │   ├── confirm-order.tsx    # One-tap order confirm screen
│   │   ├── history.tsx          # Past predictions vs actual orders
│   │   └── settings.tsx         # Notification prefs, connected apps
│   └── (modals)/
│       └── prediction-detail.tsx # Why CravingsAPI predicted this
├── components/
│   ├── PredictionCard.tsx       # The hero card showing predicted item + confidence
│   ├── CyclePhaseCard.tsx       # Phase indicator card shown above PredictionCard (opt-in users)
│   ├── CyclePhaseBar.tsx        # 28-day progress bar with phase color zones
│   ├── PeriodLogSheet.tsx       # Bottom sheet for logging period start date
│   ├── OrderConfirmSheet.tsx    # Bottom sheet for order confirmation + 5s countdown
│   ├── StreakBadge.tsx          # Gamification — prediction accuracy streak
│   ├── SignalDebugPanel.tsx     # Dev-only: shows raw signals including Sahha scores + cycle phase
│   ├── FoodItemCard.tsx         # Menu item display with macro info
│   └── ui/
│       ├── Button.tsx           # Design system button variants
│       ├── Typography.tsx       # Text scale
│       ├── Card.tsx             # Card with shadow/border variants
│       ├── BottomSheet.tsx      # Reusable bottom sheet
│       └── LoadingSkeleton.tsx  # Shimmer loading state
├── hooks/
│   ├── usePrediction.ts         # Fetches latest prediction for current user
│   ├── useOrderCart.ts          # Manages pre-built cart state + confirm flow
│   ├── useSwiggyAuth.ts         # OAuth flow, token storage in SecureStore
│   ├── useSahha.ts              # Sahha SDK init, sensor enable, profile token management
│   ├── useCyclePhase.ts         # Fetches current cycle phase + days info from backend
│   ├── useLocation.ts           # Location permission + current coords
│   └── useNotifications.ts      # FCM registration, notification handler
├── services/
│   ├── api.ts                   # Axios instance pointed at FastAPI, attaches JWT
│   ├── notifications.ts         # FCM setup, deep-link handler for notif tap
│   └── storage.ts               # SecureStore wrappers (tokens, user prefs)
├── store/
│   ├── authSlice.ts             # Redux slice: user session, Swiggy tokens
│   ├── predictionSlice.ts       # Redux slice: current prediction, confidence
│   └── cartSlice.ts             # Redux slice: pre-built cart, order status
└── app.config.ts                # Expo config: bundle ID, permissions, FCM config
```

### Key File Interactions (Mobile)

| File | Calls / Uses | Why |
|---|---|---|
| `_layout.tsx` | `useSwiggyAuth`, `authSlice` | Gates all app routes behind auth check |
| `home.tsx` | `usePrediction`, `predictionSlice` | Shows latest prediction card |
| `confirm-order.tsx` | `useOrderCart`, `cartSlice`, `api.ts` | Fetches pre-built cart, places order on confirm |
| `usePrediction.ts` | `api.ts` → `GET /predictions/latest` | Polls/fetches prediction from backend |
| `useOrderCart.ts` | `api.ts` → `POST /orders/confirm` | Submits cart confirmation to Order Orchestrator |
| `useSwiggyAuth.ts` | `storage.ts`, `api.ts` → `POST /auth/swiggy/callback` | Exchanges OAuth code, stores tokens |
| `notifications.ts` | Deep links into `confirm-order.tsx` | Notif tap routes to confirm screen with cart_id param |
| `PredictionCard.tsx` | `predictionSlice`, `StreakBadge` | Renders prediction with confidence meter |
| `OrderConfirmSheet.tsx` | `cartSlice`, `useOrderCart` | 5-second countdown + confirm/cancel |

---

## `apps/web/` — Next.js Dashboard

```
apps/web/
├── app/
│   ├── layout.tsx               # Root layout, auth
│   ├── page.tsx                 # Landing / marketing page
│   ├── dashboard/
│   │   ├── page.tsx             # User stats: prediction accuracy, savings
│   │   ├── history/page.tsx     # Order history with prediction overlay
│   │   └── signals/page.tsx     # Signal viewer (what data drives predictions)
│   └── admin/
│       ├── page.tsx             # Admin overview (model metrics, active users)
│       └── model/page.tsx       # Model performance dashboard (RMSE, AUC)
├── components/
│   ├── AccuracyChart.tsx        # Recharts line chart: predicted vs actual
│   ├── SignalTimeline.tsx       # Visual timeline of signals that drove a prediction
│   └── ModelMetricCard.tsx      # Admin: model drift, accuracy over time
└── lib/
    └── api.ts                   # fetch wrapper calling FastAPI
```

---

## `services/api/` — FastAPI Backend

```
services/api/
├── main.py                      # App entrypoint — mounts routers, CORS, middleware
├── config.py                    # Pydantic Settings — reads env vars
├── dependencies.py              # FastAPI dependency injectors (DB session, current user)
│
├── routers/
│   ├── auth.py                  # POST /auth/swiggy/callback, /auth/refresh, /auth/logout
│   ├── users.py                 # GET/PUT /users/me, /users/me/preferences
│   ├── predictions.py           # GET /predictions/latest, /predictions/history
│   ├── orders.py                # POST /orders/confirm, GET /orders/{id}/status
│   ├── signals.py               # GET /signals/latest (debug endpoint)
│   ├── cycle.py                 # POST /cycle/period, GET /cycle/current-phase, DELETE /cycle/data
│   └── webhooks.py              # POST /webhooks/fcm, POST /webhooks/sahha (HMAC-verified)
│
├── services/
│   ├── auth_service.py          # Swiggy OAuth exchange, JWT issue/verify, token refresh
│   ├── user_service.py          # User CRUD, preference management
│   ├── signal_service.py        # Orchestrates signal collection from all sources (Swiggy + weather + Sahha + cycle)
│   ├── prediction_service.py    # Calls ML inference, applies phase override layer, stores result
│   ├── notification_service.py  # Schedules FCM, manages quiet hours, rate limits, cycle-aware copy selection
│   ├── order_service.py         # Pre-builds Swiggy cart, places order via MCP client
│   ├── cycle_service.py         # Menstrual cycle phase computation, Sahha phase confirmation, period logging
│   └── scheduler.py             # APScheduler jobs — 15min prediction cycle per user
│
├── integrations/
│   ├── swiggy_mcp.py            # Swiggy MCP client — auth headers, all endpoint calls
│   ├── weather.py               # OpenWeatherMap client — current + forecast
│   ├── fcm.py                   # Firebase Admin SDK wrapper — send, track
│   └── sahha.py                 # Sahha.ai client — profile register, biomarker fetch, webhook verify
│
├── models/
│   ├── user.py                  # SQLAlchemy User model
│   ├── prediction.py            # SQLAlchemy Prediction model (stored predictions, includes cycle_phase)
│   ├── signal_snapshot.py       # SQLAlchemy SignalSnapshot (feature vector per run, includes Sahha + cycle fields)
│   ├── order.py                 # SQLAlchemy Order model (placed orders)
│   ├── notification_event.py   # SQLAlchemy NotificationEvent (open/dismiss/convert)
│   ├── sahha_connection.py      # SQLAlchemy SahhaConnection model
│   ├── cycle_profile.py         # SQLAlchemy CycleProfile model (encrypted date fields, audit hook)
│   └── cycle_period_log.py      # SQLAlchemy CyclePeriodLog model
│
├── schemas/
│   ├── auth.py                  # Pydantic request/response schemas for auth
│   ├── user.py                  # Pydantic schemas for user + preferences
│   ├── prediction.py            # Pydantic schemas for prediction output
│   ├── order.py                 # Pydantic schemas for cart + order
│   └── signal.py                # Pydantic schemas for signal snapshot
│
├── db/
│   ├── session.py               # SQLAlchemy async session factory
│   ├── migrations/              # Alembic migration files
│   └── seed.py                  # Dev seed data
│
└── tests/
    ├── test_auth.py
    ├── test_predictions.py
    ├── test_signals.py
    ├── test_orders.py
    └── test_swiggy_mcp.py
```

### Key File Interactions (Backend)

| File | Calls | Why |
|---|---|---|
| `main.py` | All routers, `scheduler.py` | Wires everything together at startup |
| `scheduler.py` | `signal_service.py`, `prediction_service.py`, `notification_service.py` | Orchestrates the 15-min prediction cycle |
| `routers/auth.py` | `auth_service.py` | Thin — just validates request shape, delegates |
| `auth_service.py` | `swiggy_mcp.py`, `db/session.py` | OAuth exchange + user upsert |
| `signal_service.py` | `swiggy_mcp.py`, `weather.py`, `healthkit.py`, `google_fit.py` | Fans out to all signal sources, normalizes |
| `prediction_service.py` | `signal_service.py`, `ml/inference/` | Gets signals, runs ONNX model, stores result |
| `notification_service.py` | `prediction_service.py`, `fcm.py`, Redis | Schedules notification + pre-cart if confidence passes |
| `order_service.py` | `swiggy_mcp.py`, Redis | Pre-builds cart (stored in Redis), places order on confirm |
| `swiggy_mcp.py` | Swiggy MCP endpoints | Central client — all Swiggy calls go through here |

---

## `ml/` — Prediction Engine

```
ml/
├── training/
│   ├── dataset_builder.py       # Pulls anonymized order data, engineers features
│   ├── train.py                 # XGBoost training loop, cross-validation
│   ├── evaluate.py              # AUC, precision@k, calibration plots
│   └── export.py                # Exports trained model to ONNX format
│
├── models/
│   ├── cravings_v1.onnx         # Production model artifact
│   └── cravings_v1_meta.json    # Feature names, version, training date, AUC
│
├── inference/
│   ├── predictor.py             # ONNX Runtime session, predict() function
│   └── feature_pipeline.py     # Feature engineering: normalize, encode, compute
│
└── notebooks/
    ├── eda.ipynb                # Exploratory analysis on order history
    └── model_eval.ipynb         # Holdout evaluation, confusion matrix
```

### Feature Vector (72 dimensions)

| Feature Group | Features |
|---|---|
| Time | hour_sin, hour_cos, dow_sin, dow_cos, is_weekend, days_since_payday |
| Weather | temp_celsius, feels_like, humidity, weather_code (OHE), is_raining |
| Order history | orders_last_7d, orders_last_30d, avg_order_value, last_order_hours_ago |
| Item preferences | top_5_category_OHE, top_10_item_OHE, cuisine_preference_vector |
| Meal timing | avg_lunch_hour, avg_dinner_hour, std_lunch_hour, std_dinner_hour |
| Health signals | sleep_hours_last_night, steps_today (0 if not connected) |
| Streak | consecutive_days_used_app, prediction_accuracy_last_10 |

### `inference/predictor.py` — predict() signature

```python
def predict(feature_vector: np.ndarray) -> PredictionResult:
    # Returns:
    # {
    #   item_id: str,         # Swiggy item ID to order
    #   item_name: str,       # Human-readable
    #   confidence: float,    # 0.0–1.0
    #   window_start: str,    # "19:30" — predicted craving window
    #   window_end: str,      # "20:30"
    #   fallback_used: bool   # True if rule-based fallback activated
    # }
```

---

## `shared/` — Cross-App Types

```
shared/
├── types/
│   ├── prediction.ts            # PredictionResult type (shared mobile + web)
│   ├── user.ts                  # User + UserPreferences type
│   └── order.ts                 # SwiggyCart, Order, OrderStatus types
└── constants/
    ├── api-routes.ts            # Enum of all API route strings
    └── thresholds.ts            # Default confidence threshold (0.55), quiet hours, etc.
```

---

## Cross-Layer Data Flow Reference

```
Notification tap (mobile)
  → notifications.ts extracts cart_id from deep link
  → navigates to confirm-order.tsx
  → useOrderCart.ts calls api.ts → POST /orders/confirm { cart_id }
  → orders.py router → order_service.py
  → order_service.py reads pre-built cart from Redis
  → calls swiggy_mcp.py → Swiggy MCP POST /food/cart/place
  → returns order_id to mobile
  → confirm-order.tsx shows success state, triggers haptic
```

# Integrations — CravingsAPI

## 1. Swiggy MCP

**Role:** Core data backbone. Provides order history, menu data, real-time item availability, cart management, and order placement.

### Auth Flow
```
User taps "Connect Swiggy"
  → App opens in-app browser: GET /auth/swiggy/start
  → Backend redirects to Swiggy OAuth2 authorize URL
  → User logs in on Swiggy's page
  → Swiggy redirects to: https://cravingsapi.app/auth/swiggy/callback?code=XYZ
  → Backend POSTs code to Swiggy token endpoint
  → Receives { access_token, refresh_token, expires_in, scope }
  → Stores encrypted tokens in swiggy_tokens table
  → Returns CravingsAPI JWT to mobile app
```

**Scopes requested:**
- `orders:read` — order history for predictions
- `menu:read` — item details, pricing, availability
- `cart:write` — pre-build and place cart
- `profile:read` — display name, city (for location fallback)

### Endpoints Used

| Swiggy MCP Endpoint | Our Usage | Called By |
|---|---|---|
| `GET /food/orders?days=180` | Order history for feature engineering | `signal_service.py` |
| `GET /food/restaurants?lat&lon` | Nearby restaurants for prediction | `prediction_service.py` |
| `GET /food/menu/{restaurant_id}` | Item details + availability check | `order_service.py` |
| `POST /food/cart/build` | Pre-build cart from prediction | `order_service.py` |
| `POST /food/cart/place` | Place confirmed order | `order_service.py` |
| `GET /food/orders/{order_id}` | Poll order status | `order_service.py` |
| `GET /instamart/orders?days=30` | Grocery history (future signal) | `signal_service.py` |
| `GET /dineout/restaurants?lat&lon` | Nearby dine-out options | (Phase 2) |

### Token Refresh
```python
# swiggy_mcp.py
async def _ensure_valid_token(user_id: str) -> str:
    token = await get_swiggy_token(user_id)
    if token.expires_at < datetime.utcnow() + timedelta(minutes=5):
        new_token = await _refresh_swiggy_token(token.refresh_token)
        await update_swiggy_token(user_id, new_token)
        return new_token.access_token
    return token.access_token
```

### Rate Limit Strategy
- Cache order history for 4 hours in Redis (stale is acceptable for features)
- Cache menu/item data for 30 min (pricing can change)
- Never call Swiggy MCP more than once per 15-min signal cycle per user
- Implement per-user request tracking in Redis: `mcp_calls:{user_id}:{hour}` counter

---

## 2. OpenWeatherMap API

**Role:** Current weather + 3-hour forecast at user location. One of the strongest predictors of food craving type.

**Endpoint:** `GET https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={key}&units=metric`

**Fields extracted:**
```python
{
    "temp_celsius": weather["main"]["temp"],
    "feels_like": weather["main"]["feels_like"],
    "humidity": weather["main"]["humidity"],
    "weather_code": weather["weather"][0]["id"],  # OWM condition code
    "is_raining": weather["weather"][0]["id"] in RAIN_CODES,  # 5xx, 3xx codes
    "description": weather["weather"][0]["description"]
}
```

**Caching:** Redis key `weather:{lat_3dp}:{lon_3dp}`, TTL 2 hours. Lat/lon rounded to 3 decimal places (~111m precision) for cache hits from nearby users.

**Fallback:** If OWM unreachable → use last cached. If no cache → use month-based seasonal defaults stored in `shared/constants/weather_defaults.json` keyed by city + month.

**Cost:** Free tier = 60 calls/min, 1M calls/month. At 15-min cycles for 1000 users → ~100K calls/day → well within free tier.

---

## 3. Firebase Cloud Messaging (FCM)

**Role:** Delivering push notifications to iOS and Android. The notification is the product's core touch point.

**Setup:**
- Firebase project: `cravingsapi-prod`
- Service account JSON stored in Railway secret `FIREBASE_SERVICE_ACCOUNT_JSON`
- iOS: APNs certificate uploaded to Firebase
- Android: `google-services.json` embedded in Expo app config

**Send flow:**
```python
# fcm.py
async def send_notification(fcm_token: str, payload: FCMPayload) -> str:
    message = messaging.Message(
        token=fcm_token,
        notification=messaging.Notification(
            title=payload.title,
            body=payload.body,
        ),
        data={
            "prediction_id": payload.prediction_id,
            "cart_id": payload.cart_id,
            "deep_link": f"cravingsapi://confirm/{payload.prediction_id}"
        },
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", badge=1)
            )
        ),
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                channel_id="predictions"
            )
        )
    )
    return messaging.send(message)
```

**Deep link scheme:** `cravingsapi://confirm/{prediction_id}` → Expo handles via `expo-linking` → navigates to `confirm-order.tsx` with `prediction_id` param.

**Event tracking:** Firebase Messaging webhooks → `POST /webhooks/fcm` → stored in `notification_events`.

---

## 4. Sahha.ai — Biomarker & Health Intelligence Platform

**Role:** The core health data layer. Sahha replaces raw HealthKit/Google Fit calls with processed, cross-platform biomarkers. It is the signal backbone for the menstrual cycle feature and the broader health intelligence pipeline. Critically, Sahha's **Reproductive biomarkers** (launching 2026) will natively provide `menstrual_phase` and `menstrual_cycle_day_number` — making our architecture future-proof.

**Homepage:** https://sahha.ai | **Docs:** https://docs.sahha.ai | **API Ref:** https://api.sahha.ai/api-docs/index.html

### Data Products Used

| Sahha Product | What It Provides | CravingsAPI Usage |
|---|---|---|
| **Scores** | 0–1 composite health scores (sleep, activity, readiness, mental_wellbeing, wellbeing) | Phase confirmation, craving intensity signal |
| **Biomarkers** | 60+ daily/weekly metrics with exact units and periodicity | Feature vector inputs — see tables below |
| **Archetypes** | Categorical/ordinal user labels (sleep_pattern, activity_level, etc.) | Meal timing model — e.g. `night_owl` shifts craving window later |
| **Insights/Trends** | Score change over time (improving / declining) | Detect phase transitions from trend slope |
| **Webhooks** | Real-time push on new biomarker/score events | Invalidate cache, trigger cycle nudges |
| **Reproductive biomarkers** *(coming 2026)* | `menstrual_phase`, `menstrual_cycle_day_number`, `menstrual_phase_days_to_next_phase`, BBT | **Will replace our self-report cycle tracking entirely** |

---

### Sahha Biomarkers We Use — Exact Field Names & Wearable Requirements

**Critical accuracy note from Sahha's Data Dictionary:** Several biomarkers require a wearable. Our feature vector degrades gracefully when these are unavailable — `sahha_has_data` flags distinguish no-Sahha from Sahha-without-wearable.

#### Scores (no wearable required — available to all users)

| Sahha Field | Unit | Periodicity | Wearable | CravingsAPI Use |
|---|---|---|---|---|
| `score.sleep` | 0–1 | daily | No | Sleep quality composite — degrades in luteal |
| `score.readiness` | 0–1 | daily | No | Recovery state — lowest in menstrual phase |
| `score.mental_wellbeing` | 0–1 | daily | No | Mental wellness — drops premenstrually |
| `score.activity` | 0–1 | daily | No | Activity level — low activity → calorie-dense prediction |
| `score.wellbeing` | 0–1 | daily | No | Holistic baseline |

#### Biomarkers — No Wearable Required

| Sahha Field | Unit | Periodicity | CravingsAPI Use |
|---|---|---|---|
| `biomarker.sleep_duration` | minute | daily | Sleep hours last night → comfort food signal |
| `biomarker.sleep_regularity` | index | weekly | Irregular sleep in luteal → stronger carb signal |
| `biomarker.sleep_start_time` | datetime | daily | Bedtime → meal timing prediction adjustment |
| `biomarker.sleep_end_time` | datetime | daily | Wake time → breakfast window prediction |
| `biomarker.sleep_debt` | hour | weekly | Accumulated deficit → comfort food override |
| `biomarker.steps` | count | daily | Physical activity proxy (no wearable) |
| `biomarker.active_hours` | hour | daily | Active hours → appetite signal |
| `biomarker.active_energy_burned` | kcal | daily | Energy expenditure → caloric need estimate |
| `biomarker.activity_sedentary_duration` | minute | daily | Sedentary time → predict higher-calorie |

#### Biomarkers — Wearable Required (used when available, zeroed when not)

| Sahha Field | Unit | Periodicity | Wearable | CravingsAPI Use |
|---|---|---|---|---|
| `biomarker.heart_rate_resting` | bpm | daily | **Yes** | Elevated RHR confirms luteal phase (physiological marker) |
| `biomarker.heart_rate_variability_sdnn` | millisecond | daily | **Yes** | Low HRV → late luteal / menstrual; high stress |
| `biomarker.heart_rate_variability_rmssd` | millisecond | daily | **Yes** | Complementary HRV metric |
| `biomarker.heart_rate_sleep` | bpm | daily | **Yes** | Nocturnal HR → recovery state |
| `biomarker.sleep_efficiency` | ratio (0–1) | daily | **Yes** | Poor efficiency in luteal |
| `biomarker.sleep_interruptions` | count | daily | **Yes** | Fragmented sleep in late luteal |
| `biomarker.body_temperature_basal` | celsius | daily | **Yes** | **BBT — clinical gold standard for cycle phase.** Rises 0.2–0.5°C at ovulation, stays elevated through luteal |
| `biomarker.skin_temperature_sleep` | celsius | daily | **Yes** | Wrist temp during sleep — detects ovulation shift |
| `biomarker.respiratory_rate_sleep` | count/minute | daily | **Yes** | Elevated in luteal |

#### Archetypes Used

| Sahha Field | Type | Periodicity | CravingsAPI Use |
|---|---|---|---|
| `archetype.sleep_pattern` | Categorical | weekly | `night_owl` → shift dinner prediction window +1.5h |
| `archetype.activity_level` | Ordinal | weekly | `sedentary` → predict comfort food more aggressively |
| `archetype.sleep_quality` | Ordinal | weekly | `poor` → amplify luteal comfort food signal |
| `archetype.sleep_regularity` | Ordinal | weekly | `irregular` → reduce craving window precision |

---

### Reproductive Biomarkers — Coming 2026 (Architecture Upgrade Path)

Sahha's Data Dictionary lists these as **"Coming 2026"**. When they launch, they replace our user-self-report cycle tracking entirely — Sahha reads from HealthKit's menstrual cycle data directly.

| Sahha Field | Unit | Periodicity | What It Gives Us |
|---|---|---|---|
| `biomarker.menstrual_phase` | none | weekly | Phase name directly — eliminates our computed phase |
| `biomarker.menstrual_cycle_day_number` | day | **daily** | Current cycle day — eliminates our day counter |
| `biomarker.menstrual_phase_days_to_next_phase` | day | **daily** | Days until phase transition — powers notifications |
| `biomarker.menstrual_phase_day_number` | day | daily | Day within current phase |
| `biomarker.menstrual_cycle_start_date` | date | monthly | Cycle start — eliminates user self-report |
| `biomarker.menstrual_cycle_length` | day | monthly | Average cycle length |
| `biomarker.menstruation_period_start_date` | date | monthly | Period start date |
| `biomarker.fertile_window_start_date` | date | monthly | Ovulatory window — useful for Dineout social eating prediction |

**Migration plan (when 2026 biomarkers launch):**
1. Enable `reproductive` sensor in Sahha SDK — reads from Apple Health menstrual cycle tracking natively
2. `cycle_service.py` → check for Sahha `menstrual_phase` biomarker first; fall back to our computed phase if absent
3. `cycle_profiles.last_period_start` becomes optional — Sahha provides it
4. No breaking changes — our phase override layer uses the phase name regardless of source

---

### Profile Registration Flow

```python
# integrations/sahha.py — called when user completes onboarding

async def register_sahha_profile(user_id: str, age: int | None, gender: str | None) -> str:
    """Create a Sahha profile for the user. Returns profile_token."""
    response = await sahha_post("/oauth/profile/register", json={
        "externalId": f"cravingsapi_user_{user_id}",
        "demographics": {k: v for k, v in {"age": age, "gender": gender}.items() if v},
    })
    return response["profileToken"]
```

The `profileToken` is stored in `sahha_connections.profile_token` (encrypted at rest). It is passed to the mobile SDK for passive data collection — no user action required after initial permission grant.

### Mobile SDK Setup (React Native)

```typescript
// hooks/useSahha.ts
import Sahha, { SahhaSensor } from 'sahha-react-native';

export const initSahha = async () => {
  await Sahha.configure({ environment: 'production' });

  await Sahha.authenticate(
    process.env.EXPO_PUBLIC_SAHHA_APP_ID!,
    process.env.EXPO_PUBLIC_SAHHA_APP_SECRET!,
  );

  // Core sensors — no wearable needed for sleep, activity
  // heart sensor data quality depends on wearable availability
  await Sahha.enableSensors([
    SahhaSensor.sleep,
    SahhaSensor.heart,
    SahhaSensor.activity,
    // SahhaSensor.reproductive  ← enable when Sahha launches this in 2026
  ]);
};
```

Sahha SDK reads from Apple HealthKit (iOS) or Google Health Connect (Android) in the background. Wearable-gated biomarkers (HRV, resting HR, BBT) return null if user has no wearable — handled gracefully via `sahha_has_wearable` flag.

### Biomarker Fetch (Backend — every 15 min per active user)

```python
# integrations/sahha.py

SAHHA_BASE = "https://api.sahha.ai"

# Biomarkers available without a wearable
BIOMARKERS_NO_WEARABLE = [
    "sleep_duration", "sleep_regularity", "sleep_debt",
    "sleep_start_time", "sleep_end_time",
    "steps", "active_hours", "active_energy_burned",
    "activity_sedentary_duration",
]

# Biomarkers requiring a wearable — fetched opportunistically
BIOMARKERS_WEARABLE = [
    "heart_rate_resting", "heart_rate_variability_sdnn", "heart_rate_variability_rmssd",
    "heart_rate_sleep", "sleep_efficiency", "sleep_interruptions",
    "body_temperature_basal", "skin_temperature_sleep", "respiratory_rate_sleep",
]

SCORES_NEEDED = ["sleep", "readiness", "mental_wellbeing", "activity", "wellbeing"]

ARCHETYPES_NEEDED = ["sleep_pattern", "activity_level", "sleep_quality", "sleep_regularity"]

async def get_health_signals(user_id: str, has_wearable: bool) -> SahhaSignals:
    external_id = f"cravingsapi_user_{user_id}"
    today = date.today().isoformat()
    headers = {"Authorization": f"account {settings.SAHHA_ACCOUNT_TOKEN}"}

    biomarker_types = BIOMARKERS_NO_WEARABLE + (BIOMARKERS_WEARABLE if has_wearable else [])

    biomarkers_raw, scores_raw, archetypes_raw = await asyncio.gather(
        sahha_get("/profile/biomarker",
            params={"externalId": external_id, "types": ",".join(biomarker_types), "startDateTime": today},
            headers=headers),
        sahha_get("/profile/score",
            params={"externalId": external_id, "types": ",".join(SCORES_NEEDED), "startDateTime": today},
            headers=headers),
        sahha_get("/profile/archetypes",
            params={"externalId": external_id, "types": ",".join(ARCHETYPES_NEEDED)},
            headers=headers),
    )

    return SahhaSignals(
        # Scores (no wearable)
        sleep_score=extract_score(scores_raw, "sleep"),
        readiness_score=extract_score(scores_raw, "readiness"),
        mental_wellbeing_score=extract_score(scores_raw, "mental_wellbeing"),
        activity_score=extract_score(scores_raw, "activity"),
        # Biomarkers — no wearable
        sleep_duration_min=extract_biomarker(biomarkers_raw, "sleep_duration"),
        sleep_regularity_index=extract_biomarker(biomarkers_raw, "sleep_regularity"),
        sleep_debt_hours=extract_biomarker(biomarkers_raw, "sleep_debt"),
        steps=extract_biomarker(biomarkers_raw, "steps"),
        active_hours=extract_biomarker(biomarkers_raw, "active_hours"),
        sedentary_minutes=extract_biomarker(biomarkers_raw, "activity_sedentary_duration"),
        # Biomarkers — wearable (None if not available)
        hrv_sdnn_ms=extract_biomarker(biomarkers_raw, "heart_rate_variability_sdnn"),
        hrv_rmssd_ms=extract_biomarker(biomarkers_raw, "heart_rate_variability_rmssd"),
        resting_hr_bpm=extract_biomarker(biomarkers_raw, "heart_rate_resting"),
        sleep_efficiency=extract_biomarker(biomarkers_raw, "sleep_efficiency"),
        bbt_celsius=extract_biomarker(biomarkers_raw, "body_temperature_basal"),
        skin_temp_sleep=extract_biomarker(biomarkers_raw, "skin_temperature_sleep"),
        # Archetypes
        sleep_pattern=extract_archetype(archetypes_raw, "sleep_pattern"),
        activity_level=extract_archetype(archetypes_raw, "activity_level"),
        # Meta
        has_wearable=has_wearable,
        has_sahha_data=True,
    )
```

**Caching:** `sahha:{user_id}:signals` in Redis, TTL 30 min (biomarkers update hourly on Sahha's side).

### BBT — The Most Powerful Cycle Confirmation Signal

`body_temperature_basal` (basal body temperature) is clinically recognized as the gold standard for cycle phase detection:
- **Pre-ovulation (follicular):** BBT ~36.2–36.5°C
- **Ovulation:** BBT rises 0.2–0.5°C — visible spike in daily readings
- **Post-ovulation (luteal):** BBT stays elevated at ~36.5–37.0°C
- **Period start:** BBT drops back to baseline

When a user has a wearable providing `body_temperature_basal`, we can:
1. Detect ovulation independently of logged period date
2. Confirm luteal phase with physiological certainty
3. Predict period onset 1–2 days early (BBT drops before bleeding starts)

```python
def bbt_phase_signal(bbt_series: list[float]) -> BbtPhaseSignal:
    """Analyse last 14 days of BBT readings."""
    if len(bbt_series) < 7:
        return BbtPhaseSignal(confident=False)

    baseline = np.mean(bbt_series[:7])
    recent = np.mean(bbt_series[-3:])
    delta = recent - baseline

    if delta > 0.2:
        return BbtPhaseSignal(phase_confirmed="luteal", confident=True, delta_celsius=delta)
    elif delta < -0.15 and recent < baseline:
        return BbtPhaseSignal(phase_confirmed="menstrual_onset", confident=True, delta_celsius=delta)
    else:
        return BbtPhaseSignal(phase_confirmed="follicular_or_unknown", confident=delta < 0.1)
```

### Sahha Webhook Handler

```python
# routers/webhooks.py

@router.post("/webhooks/sahha")
async def sahha_webhook(request: Request):
    signature = request.headers.get("X-Signature")
    body = await request.body()
    expected = hmac.new(settings.SAHHA_WEBHOOK_SECRET.encode(), body, sha256).hexdigest()
    if not hmac.compare_digest(signature, expected):
        raise HTTPException(403)

    external_id = request.headers.get("X-External-Id")
    event_type = request.headers.get("X-Event-Type")
    user_id = external_id.replace("cravingsapi_user_", "")

    if event_type == "BiomarkerCreatedIntegrationEvent":
        await redis.delete(f"sahha:{user_id}:signals")
        payload = await request.json()

        # BBT spike → auto-confirm ovulation
        if payload.get("type") == "body_temperature_basal":
            await cycle_service.handle_bbt_update(user_id, payload["value"])

        # Sharp readiness drop → suggest period start nudge
        if payload.get("type") == "readiness" and payload["value"] < 0.35:
            await cycle_service.maybe_suggest_period_start(user_id)

    return {"ok": True}
```

### Sahha Biomarkers vs Cycle Phase — Correlation Table

| Sahha Signal | Menstrual | Follicular | Ovulatory | Luteal |
|---|---|---|---|---|
| `score.readiness` | Very low (< 0.35) | Rising | High (> 0.72) | Dropping (0.40–0.60) |
| `score.sleep` | Low (< 0.55) | Improving | Good (> 0.70) | Disrupted (< 0.60) |
| `score.mental_wellbeing` | Low | Neutral–high | High | Low → very low (PMS) |
| `score.activity` | Low | Rising | High | Variable, often low |
| `biomarker.heart_rate_resting` *(wearable)* | Elevated | Normal | Low-normal | Elevated (+2–5 bpm) |
| `biomarker.heart_rate_variability_sdnn` *(wearable)* | Very low | Rising | Peak | Declining |
| `biomarker.body_temperature_basal` *(wearable)* | Dropping | Low baseline | Spikes +0.2°C | Elevated (+0.3°C above follicular) |
| `biomarker.sleep_regularity` | Disrupted | Good | Good | Disrupted |
| `biomarker.sleep_debt` | High | Low | Low | Building |

When ≥ 3 Sahha signals match the expected phase pattern → `phase_confidence_multiplier` = 1.4.
When 0–1 signals match → multiplier = 0.85 (hedge prediction, phase may be transitioning).

---

## 5. Supabase (PostgreSQL + Auth)

**Role:** Primary database + user authentication.

**Auth configuration:**
- Email/password disabled (Swiggy OAuth is the only sign-in method)
- JWTs issued by Supabase with 1-hour expiry
- Row Level Security (RLS) enabled on all tables — users can only query their own rows

**RLS example:**
```sql
-- predictions table
CREATE POLICY "Users see own predictions"
ON predictions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert"
ON predictions FOR INSERT
WITH CHECK (true);  -- backend uses service role key
```

**Connection:** SQLAlchemy async with `asyncpg`. Pool size: 5–20 connections.

---

## 7. Upstash Redis

**Role:** Cart pre-building (TTL keys), notification scheduling, signal caching, rate limiting.

**Connection:** Via Upstash REST API (HTTP-based, no persistent connection needed) using `upstash-redis` Python SDK.

**Key design principles:**
- All keys have explicit TTL — no permanent Redis state
- Prediction lock keys prevent concurrent signal collection: `pred_lock:{user_id}` with 14-min TTL (just under the 15-min cycle)
- Cart keys: `cart:{prediction_id}` — 90 min TTL
- Weather cache: `weather:{lat}:{lon}` — 2h TTL
- Notification rate: `notif_count:{user_id}:{YYYYMMDD}` — 24h TTL

---

## Integration Health Dashboard

The web admin dashboard (`/admin`) shows:

| Metric | Source | Alert Threshold |
|---|---|---|
| Swiggy MCP success rate | `notification_events` + error log | < 95% |
| OWM cache hit rate | Redis `weather:*` key count vs requests | < 80% |
| FCM delivery rate | Firebase analytics | < 98% |
| Sahha profile connection rate | `sahha_connections.is_active` count | Informational |
| Cycle tracking opt-in rate (female users) | `cycle_profiles` count / eligible users | Informational |
| Sahha webhook delivery | `webhooks/sahha` 2xx rate | < 98% |
| Average prediction confidence | `predictions.confidence` avg (1d) | < 0.60 |
| Swiggy token refresh failures | Sentry error count | > 5/hour |

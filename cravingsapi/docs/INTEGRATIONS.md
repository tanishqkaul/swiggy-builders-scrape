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

## 4. Apple HealthKit

**Role (opt-in):** Sleep duration from previous night, step count today. Both are meaningful predictors of food choice.

**Permissions requested:**
- `HKQuantityTypeIdentifierStepCount` (steps)
- `HKCategoryTypeIdentifierSleepAnalysis` (sleep)

**Mobile-side (React Native):**
```typescript
// hooks/useHealthSignals.ts
import AppleHealthKit from 'react-native-health';

const getHealthSignals = async (): Promise<HealthSignals> => {
  const steps = await AppleHealthKit.getStepCount({
    date: new Date().toISOString(),
  });
  const sleep = await AppleHealthKit.getSleepSamples({
    startDate: subDays(new Date(), 1).toISOString(),
    endDate: new Date().toISOString(),
  });
  return {
    steps_today: steps.value,
    sleep_hours: computeSleepHours(sleep),
  };
};
```

**Sent to backend:** Via `POST /signals/health` with the above values. Backend stores in signal snapshot. Never raw HealthKit data leaves device — only computed aggregates.

---

## 5. Google Fit

**Role:** Same as HealthKit but for Android.

**OAuth scopes:**
- `https://www.googleapis.com/auth/fitness.activity.read` (steps)
- `https://www.googleapis.com/auth/fitness.sleep.read` (sleep)

**Mobile-side:** `react-native-google-fit` package. Same computed-aggregate pattern as HealthKit.

**Token storage:** Access + refresh tokens in `SecureStore`, not sent to backend raw.

---

## 6. Supabase (PostgreSQL + Auth)

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
| HealthKit/Fit connection rate | `health_connections.is_active` count | Informational |
| Average prediction confidence | `predictions.confidence` avg (1d) | < 0.60 |
| Swiggy token refresh failures | Sentry error count | > 5/hour |

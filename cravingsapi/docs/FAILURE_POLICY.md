# Failure Policy — CravingsAPI

## Philosophy

Every failure mode has a graceful degradation path. The user should **always see a prediction** even if the ML model is down. The user should **always be able to order** even if the pre-built cart expired. No white screens. No silent failures.

---

## Failure Matrix

### 1. Swiggy MCP Unavailable

| Scenario | Detection | Response |
|---|---|---|
| MCP returns 5xx | HTTP status ≥ 500 | Retry 3x with exponential backoff (1s, 2s, 4s). If all fail → use cached order history (last successful fetch, stored in DB). Log to Sentry. |
| MCP returns 429 (rate limit) | HTTP 429 | Back off for `Retry-After` header duration. Reschedule signal collection to next window. |
| Swiggy OAuth token expired | 401 on any MCP call | Auto-refresh using `refresh_token`. If refresh fails → mark user `needs_reauth`, send in-app notification to re-login. |
| Cart pre-build fails | 4xx/5xx on cart endpoint | Store prediction without pre-built cart. On user tap: build cart at order time (slower, but works). Show "Building your order…" spinner. |
| Order placement fails | 4xx/5xx on order endpoint | Show error bottom sheet: "Something went wrong — open Swiggy directly?" with deep link to Swiggy app pre-filled. |

### 2. ML Prediction Engine Failure

| Scenario | Detection | Response |
|---|---|---|
| ONNX model file missing/corrupt | Load error at startup | Fall back to rule-based predictor immediately. Alert via Sentry. No user impact. |
| Inference error (shape mismatch, etc.) | Exception in `predictor.py` | Catch, log, fall back to rule-based. Never surface stack trace to user. |
| Confidence below threshold | `confidence < user_threshold` | Do not send notification. Reschedule for next 15-min window. If 3 consecutive failures → send a "what are you craving?" manual prompt once per day. |
| Feature vector computation fails | Exception in `feature_pipeline.py` | Use last stored `signal_snapshot` if < 4 hours old. If older → use partial signals (skip missing). |

**Rule-based fallback logic:**
```python
def rule_based_predict(user_id: str, hour: int, dow: int) -> PredictionResult:
    # Query: most frequently ordered item at (hour±2, dow) in last 90 days
    # If no match at hour: use top item overall
    # Confidence: 0.40 (always signals fallback_used=True in DB)
```

### 3. Signal Source Failures

| Source | Failure | Degradation |
|---|---|---|
| OpenWeatherMap | Timeout / 5xx | Use last cached weather (Redis, TTL 2h). If no cache → use seasonal defaults (month-based average temp for user's city). Weather features zeroed in feature vector. |
| Apple HealthKit | No permission / API error | Skip health features. Set `sleep_hours=0`, `steps_today=0` in feature vector. `health_signals_enabled` stays true in prefs (don't auto-disable). |
| Google Fit | OAuth expired | Same as HealthKit. Prompt reauth in next app open, not a push. |
| Location unavailable | Permission denied | Use last known location. If never set → use city-level default (user's account city from Swiggy profile). |

### 4. Notification System Failures

| Scenario | Response |
|---|---|
| FCM token invalid/expired | Catch FCM `InvalidRegistration` → clear `fcm_token` from user row. Device will re-register on next app open. |
| FCM send failure | Retry once after 30s. If fail again → log to Sentry. Skip this notification cycle (do not double-send). |
| Notification delivered but no cart in Redis | User taps → `useOrderCart` calls `GET /orders/prebuild` → builds cart on-demand. "Hang on, preparing your order…" state shown for up to 5s. |
| User has exceeded daily cap | Skip scheduling. Do not notify. |
| User in quiet hours | Defer: schedule notification for `quiet_hours_end` + 15min. |

### 5. Database Failures

| Scenario | Response |
|---|---|
| PostgreSQL connection timeout | Retry with new connection from pool. If pool exhausted → return 503 with `Retry-After: 5`. |
| Write fails (prediction insert) | Log to Sentry with prediction data. Prediction cycle skipped. No user-facing error. |
| Supabase Auth outage | Cache valid JWTs for 5 minutes in Redis. Graceful degradation for authenticated users already in session. New logins fail with friendly error. |
| Migration fails | Block startup. Alert on-call. Never run with mismatched schema. |

---

## Error Response Contract

All API errors follow this shape:

```json
{
  "error": {
    "code": "CART_EXPIRED",
    "message": "Your pre-built cart has expired. We're rebuilding it now.",
    "retry_after_ms": 3000,
    "support_id": "pred_01HX..."
  }
}
```

**Error codes:**
| Code | HTTP | Meaning |
|---|---|---|
| `UNAUTHENTICATED` | 401 | JWT missing or invalid |
| `SWIGGY_REAUTH_REQUIRED` | 401 | Swiggy token unrefreshable |
| `PREDICTION_UNAVAILABLE` | 503 | No prediction yet, check back |
| `CART_EXPIRED` | 410 | Pre-built cart TTL exceeded |
| `ORDER_FAILED` | 502 | Swiggy MCP order placement failed |
| `RATE_LIMITED` | 429 | Too many requests from this user |
| `VALIDATION_ERROR` | 422 | Request payload invalid |
| `INTERNAL_ERROR` | 500 | Unexpected — support_id logged to Sentry |

---

## SLAs

| Metric | Target | Measurement |
|---|---|---|
| API p50 latency | < 80ms | Sentry performance |
| API p99 latency | < 800ms | Sentry performance |
| Prediction inference p50 | < 8ms | Internal timing |
| Notification delivery (FCM) | < 10s from scheduled time | FCM event log |
| Signal collection success rate | > 95% | DB signal_snapshot count |
| Prediction coverage (users with ≥1 prediction/day) | > 80% | Daily analytics query |
| Order success rate (confirmed orders) | > 98% | `orders.status` tracking |

---

## On-Call Runbook

### Alert: High Sentry error rate on `swiggy_mcp.py`
1. Check Swiggy MCP status page.
2. Check if tokens are expiring — query `swiggy_tokens` for `expires_at < now() + interval '5 min'`.
3. Run manual token refresh: `python -m services.api.services.auth_service refresh_all`.
4. If MCP is down: deploy feature flag `DISABLE_ORDER_PLACEMENT=true` → cart-build still works, order button opens Swiggy directly.

### Alert: Prediction coverage drops below 70%
1. Check `scheduler.py` logs — is the 15-min job running?
2. Check `signal_service.py` — weather API keys valid?
3. Check ML model: `python -m ml.inference.predictor health` → should return OK.
4. Force-run prediction for all users: `python -m services.api.services.scheduler run_now`.

### Alert: Redis memory > 80%
1. Inspect key distribution: `redis-cli --scan --pattern 'cart:*' | wc -l`.
2. Check TTLs are set: `redis-cli DEBUG SLEEP 0` then scan for keys with TTL -1.
3. Flush expired carts: `python -m services.api.db.cache flush_expired_carts`.

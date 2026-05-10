# Testing Strategy — CravingsAPI

## Testing Pyramid

```
        ┌──────────────┐
        │   E2E Tests  │   5%  — full flow on real devices (Detox)
        ├──────────────┤
        │ Integration  │   25% — API + DB + MCP mock (pytest)
        ├──────────────┤
        │  Unit Tests  │   50% — services, ML pipeline, feature eng
        ├──────────────┤
        │ ML Validation│   20% — model accuracy, calibration, drift
        └──────────────┘
```

---

## Unit Tests (`services/api/tests/`)

### `test_auth.py`
- Swiggy OAuth callback: valid code → tokens stored → JWT returned
- Swiggy OAuth callback: invalid code → 400 error
- Token refresh: near-expiry token → auto-refreshes → returns new access token
- Token refresh: expired refresh token → 401 SWIGGY_REAUTH_REQUIRED
- JWT expiry: expired JWT → 401 UNAUTHENTICATED

### `test_signals.py`
- Feature vector has correct dimension (72)
- Weather unavailable → uses defaults, no exception
- Health signals unavailable → zeroed out in vector, no exception
- Signal snapshot written to DB on success
- Duplicate signal collection blocked by Redis pred_lock

### `test_predictions.py`
- ONNX inference returns valid PredictionResult shape
- Confidence < threshold → no notification scheduled
- Confidence ≥ threshold → notification job enqueued
- Fallback predictor returns most-ordered item for hour/dow
- Fallback triggered when ONNX fails → `fallback_used=True` in result
- Prediction stored to DB with correct user_id, model_version

### `test_orders.py`
- Cart pre-build: Swiggy MCP returns cart → stored in Redis with 90-min TTL
- Cart pre-build: Swiggy MCP fails → order_service gracefully skips, prediction continues
- Confirm order: valid cart_id → Swiggy MCP called → order_id returned
- Confirm order: expired cart (TTL elapsed) → on-demand rebuild attempted
- Confirm order: item sold out → 502 ORDER_FAILED with suggestion
- Order status: polls Swiggy MCP → returns current status

### `test_swiggy_mcp.py`
- Valid token → order history returned and parsed
- 401 from MCP → token refresh triggered
- 429 from MCP → exponential backoff, then retry
- 5xx from MCP (3x) → raises SwiggyMCPError, logged to Sentry
- Token decryption: round-trip encrypt/decrypt produces original token

---

## Integration Tests

Run against:
- Real Supabase instance (test project, separate from prod)
- Redis (Upstash test DB)
- Swiggy MCP: mocked with `pytest-httpx` (deterministic responses)
- OpenWeatherMap: mocked

### Scenarios
1. **Full prediction cycle:** Signal collection → feature engineering → ONNX inference → prediction stored → notification scheduled → cart pre-built in Redis
2. **Order flow:** Notification scheduled → cart retrieved from Redis → order confirmed → `orders` table updated → `predictions.outcome = 'ordered'`
3. **Auth flow:** OAuth callback with mock Swiggy tokens → JWT issued → protected route accessible → JWT expire → 401 → re-auth
4. **Rate limiting:** 11 rapid calls to `POST /orders/confirm` → 11th returns 429
5. **Graceful degradation:** OWM mock returns 500 → signal uses defaults → prediction still runs

---

## ML Validation (`ml/notebooks/model_eval.ipynb`)

### Offline Metrics (on holdout set)
| Metric | Target | Measurement |
|---|---|---|
| Top-1 accuracy | ≥ 55% | Predicted item = ordered item |
| Top-3 accuracy | ≥ 75% | Ordered item in top 3 predictions |
| Calibration | Brier score < 0.15 | Predicted prob vs actual outcome |
| Category accuracy | ≥ 70% | Predicted cuisine category correct |
| AUC-ROC | ≥ 0.78 | Binary (ordered this item or not) |

### Online Metrics (live, tracked daily)
| Metric | Target |
|---|---|
| Notification → order rate | ≥ 15% |
| Notification → dismiss rate | < 40% |
| Prediction → any order within 2h | ≥ 25% |
| User-reported accuracy (in-app rating) | ≥ 4.0/5 |

### Drift Detection
- Weekly job compares feature distribution (current 7d vs previous 30d)
- Alert if any feature's KL divergence > 0.2
- Alert if top-1 accuracy on weekly cohort drops > 10 percentage points from baseline
- Retrain triggered automatically if drift detected (manual approval before deploy)

---

## E2E Tests (Detox — iOS simulator)

### Test: Full Onboarding + First Prediction
```
1. Cold launch app
2. Tap "Connect Swiggy" → WebView opens (mocked OAuth server)
3. Complete OAuth flow → app receives JWT
4. Allow location → mock location set to Mumbai
5. Skip health connection
6. Home screen loads
7. Wait for prediction (seeded in mock API)
8. PredictionCard visible with item name and confidence bar
```

### Test: One-Tap Order
```
1. Authenticated session (seeded)
2. Pre-built cart in mock Redis
3. Tap notification (simulated deep link)
4. OrderConfirmSheet visible
5. Tap "Confirm"
6. Mock Swiggy MCP returns order_id
7. Success animation plays
8. Order appears in History screen
```

### Test: Offline Graceful Degradation
```
1. Authenticated session
2. Disable network
3. Pull to refresh on Home
4. "You're offline" toast appears
5. Cached prediction still shown
6. Re-enable network
7. Pull to refresh → prediction updates
```

---

## CI Pipeline

```yaml
# .github/workflows/ci.yml
on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - pytest services/api/tests/ --cov=services/api --cov-fail-under=80
      - pip-audit (fail on HIGH/CRITICAL CVEs)

  ml-validation:
    runs-on: ubuntu-latest
    steps:
      - python ml/training/evaluate.py --holdout data/holdout.parquet
      - fail if top-1 accuracy < 0.50

  mobile-tests:
    runs-on: macos-latest
    steps:
      - jest --testPathPattern="apps/mobile" --coverage
      - fail if coverage < 70%

  type-check:
    runs-on: ubuntu-latest
    steps:
      - tsc --noEmit (apps/mobile + apps/web)
```

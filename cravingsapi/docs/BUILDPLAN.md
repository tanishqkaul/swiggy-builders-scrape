# Build Plan — CravingsAPI

## Phases Overview

| Phase | Duration | Goal | Definition of Done |
|---|---|---|---|
| 0 — Foundations | Day 1, 0–4h | Repo, auth, Swiggy MCP connected | Can fetch user's order history |
| 1 — Signal Engine | Day 1, 4–8h | All signals aggregated into feature vector | Signal snapshot stored in DB |
| 2 — Prediction Core | Day 1, 8–14h | Rule-based + ML prediction running | Prediction stored with confidence |
| 3 — Notifications | Day 1, 14–18h | Push notification fires with pre-built cart | User receives notif on device |
| 4 — One-Tap Order | Day 1, 18–22h | Full end-to-end order flow works | Order confirmed via Swiggy MCP |
| 5 — Mobile UI | Day 2, 0–8h | Polished React Native app | All screens implemented, design system applied |
| 6 — Demo Prep | Day 2, 8–12h | Demo script, seeded data, web dashboard | 60-second demo reproducible |

---

## Hackathon Track (24-Hour Sprint)

### Hour 0–1: Setup
- [ ] `git init` + monorepo structure
- [ ] Railway project created, env vars set
- [ ] Supabase project created, schema migrated
- [ ] Upstash Redis provisioned
- [ ] Swiggy MCP credentials obtained, basic auth tested
- [ ] Expo app initialized with navigation skeleton

### Hour 1–4: Phase 0 — Auth + MCP Connection
- [ ] `swiggy_mcp.py` client with auth headers
- [ ] `GET /orders/history` returning real data
- [ ] Swiggy OAuth2 flow (web-based redirect) working
- [ ] `swiggy_tokens` table populated for test user
- [ ] `POST /auth/swiggy/callback` endpoint live

**Milestone check:** Curl against API returns last 10 Swiggy orders for the test account.

### Hour 4–8: Phase 1 — Signal Engine
- [ ] `weather.py` — OpenWeatherMap current + forecast
- [ ] `signal_service.py` — fan-out to all sources, normalize
- [ ] Feature engineering pipeline (`ml/inference/feature_pipeline.py`)
- [ ] `signal_snapshots` table being written every 15 minutes
- [ ] Health signals stubbed out (returns 0/null) — real connection is Phase 6

**Milestone check:** `/signals/latest` returns a 72-dim feature vector for the test user.

### Hour 8–14: Phase 2 — Prediction Core
- [ ] Rule-based fallback predictor (most-ordered item at current hour × weekday from history)
- [ ] XGBoost model trained on synthetic order data (real data pending Swiggy approval)
- [ ] ONNX export + `predictor.py` ONNX Runtime inference
- [ ] `prediction_service.py` combining signals → feature → model → result
- [ ] `predictions` table populated
- [ ] `GET /predictions/latest` returning JSON with confidence

**Milestone check:** Calling prediction service returns `{ item_name: "Chicken Biryani", confidence: 0.74, window: "19:30–20:30" }`.

### Hour 14–18: Phase 3 — Notifications
- [ ] Firebase project created, FCM credentials set
- [ ] `fcm.py` wrapper — send message by FCM token
- [ ] `notification_service.py` — threshold check, quiet hours, daily cap
- [ ] APScheduler job running every 15 min (can reduce to 5 min for demo)
- [ ] Notification copy templates wired up
- [ ] Pre-built cart stored in Redis (`cart:{prediction_id}`)
- [ ] Push notification fires on test device

**Milestone check:** Wait 15 min → test device receives notification with item name.

### Hour 18–22: Phase 4 — One-Tap Order
- [ ] `order_service.py` reads pre-built cart from Redis
- [ ] Swiggy MCP cart/place endpoint integration
- [ ] `POST /orders/confirm` route live
- [ ] Deep link from notification → app opens confirm screen
- [ ] 5-second countdown → order placed → `orders` table updated

**Milestone check:** Tap notification → confirm screen → order appears in Swiggy app.

### Hour 22–30: Phase 5 — Mobile UI
- [ ] `PredictionCard.tsx` with confidence bar
- [ ] `OrderConfirmSheet.tsx` with countdown
- [ ] Home screen with today's prediction
- [ ] Onboarding: location → notifications → Swiggy auth
- [ ] History screen: past predictions vs actual orders
- [ ] `StreakBadge` gamification
- [ ] Dark theme applied consistently

### Hour 30–36: Phase 6 — Polish + Demo
- [ ] Seed 90 days of synthetic order history for demo account
- [ ] Force-trigger prediction on demo account
- [ ] Web dashboard showing accuracy metrics
- [ ] 60-second demo script practiced and timed
- [ ] Sentry error tracking live
- [ ] README with screenshots and demo video link

---

## Demo Script (60 seconds)

```
[0:00] "I order Swiggy every day. But I always figure out what I want too late."

[0:08] "CravingsAPI predicts what you'll crave — before you're hungry."

[0:14] Open app → show home screen with today's prediction:
       "Chicken Biryani · Behrouz Biryani · 87% confident"

[0:20] "It's 7:15 PM on a rainy Thursday. Here's why it predicted this:"
       → tap prediction → signal detail view
       → show: weather (rainy), day (Thu), past orders highlight

[0:32] "Now watch what happens."
       → switch to notification → receive push on device live
       "You'll probably want Biryani around 8 PM — tap to pre-order"

[0:42] Tap notification → OrderConfirmSheet slides up
       → 5-second countdown
       → tap Confirm

[0:52] "Order placed." → show Swiggy order confirmation screen

[0:58] "This works because Swiggy MCP gives us real menu data,
        real order history, and real cart placement. Not a mockup."

[1:00] Done.
```

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Swiggy MCP order placement blocked | Medium | High | Demo with mock order + real cart pre-build to show it works |
| ML model not accurate enough on synthetic data | High | Medium | Rule-based fallback is the demo; ML is bonus |
| FCM delivery delayed in demo | Low | High | Pre-send notification 2 min before demo; trigger manually |
| Expo build fails | Medium | High | Keep web demo fallback ready |
| Swiggy OAuth flow broken on mobile | Medium | High | Use pre-authenticated session for demo account |

---

## Post-Hackathon Roadmap

| Feature | Effort | Value |
|---|---|---|
| Real HealthKit integration | M | High (accuracy++) |
| Per-user model fine-tuning | L | High |
| Group order prediction (couples, families) | M | Medium |
| Menstrual cycle tracking (opt-in, female users) | L | High controversy, high accuracy |
| WhatsApp delivery of notification | S | High (distribution) |
| B2B API (restaurants pay for demand prediction) | L | High (monetization) |
| Apple Watch complication | M | High (viral) |

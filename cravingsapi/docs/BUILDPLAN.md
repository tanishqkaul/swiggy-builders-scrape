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
- [ ] Supabase project created, schema migrated (includes `cycle_profiles`, `sahha_connections`)
- [ ] Upstash Redis provisioned
- [ ] Swiggy MCP credentials obtained, basic auth tested
- [ ] **Sahha account created at app.sahha.ai → App ID + App Secret obtained**
- [ ] **Sahha webhook URL registered: `https://api.cravingsapi.app/webhooks/sahha`**
- [ ] Expo app initialized with navigation skeleton

### Hour 1–4: Phase 0 — Auth + MCP Connection
- [ ] `swiggy_mcp.py` client with auth headers
- [ ] `GET /orders/history` returning real data
- [ ] Swiggy OAuth2 flow (web-based redirect) working
- [ ] `swiggy_tokens` table populated for test user
- [ ] `POST /auth/swiggy/callback` endpoint live

**Milestone check:** Curl against API returns last 10 Swiggy orders for the test account.

### Hour 4–8: Phase 1 — Signal Engine + Sahha + Cycle
- [ ] `weather.py` — OpenWeatherMap current + forecast
- [ ] **`sahha.py` — Sahha profile registration + biomarker fetch (sleep_score, readiness, HRV, resting_hr)**
- [ ] **`cycle_service.py` — phase computation from `cycle_profiles`, `get_sahha_phase_confidence()`**
- [ ] `signal_service.py` — fan-out to all sources including Sahha + cycle, normalize
- [ ] Feature engineering pipeline (`ml/inference/feature_pipeline.py`) — updated to 95-dim
- [ ] `signal_snapshots` table being written every 15 minutes with Sahha + cycle columns
- [ ] **Demo: manually set `cycle_profiles.last_period_start` for demo user to day 20 → phase = luteal**

**Milestone check:** `/signals/latest` returns a 95-dim feature vector showing `cycle_phase=luteal`, Sahha scores populated for the test user.

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
- [ ] **`CyclePhaseCard.tsx` above PredictionCard — phase name, day count, progress bar in phase color**
- [ ] **`PeriodLogSheet.tsx` — date picker for logging period start**
- [ ] `OrderConfirmSheet.tsx` with countdown
- [ ] Home screen with today's prediction
- [ ] Onboarding: location → Swiggy auth → **Sahha connect → cycle date (optional)**
- [ ] History screen: past predictions vs actual orders
- [ ] `StreakBadge` gamification
- [ ] **Settings → Cycle Tracking section with log/delete options**
- [ ] Dark theme applied consistently with phase-specific accent colors

### Hour 30–36: Phase 6 — Polish + Demo
- [ ] Seed 90 days of synthetic order history for demo account
- [ ] Force-trigger prediction on demo account
- [ ] Web dashboard showing accuracy metrics
- [ ] 60-second demo script practiced and timed
- [ ] Sentry error tracking live
- [ ] README with screenshots and demo video link

---

## Demo Script (90 seconds — cycle feature is the reveal)

```
[0:00] "Every app predicts what you'll order based on what you ordered before.
        That's table stakes."

[0:06] "CravingsAPI goes deeper."

[0:10] Open app → show home screen.
       CyclePhaseCard visible at top: "🌙 Luteal Phase · Day 22 · 6 days until period"
       PredictionCard below: "Dark Chocolate Maggi · Swiggy Instamart · 91% confident"

[0:18] "Our demo user is in her luteal phase — day 22.
        Progesterone is peaking. Carb and chocolate cravings are physiologically inevitable."

[0:26] Tap prediction → signal detail view.
       Show: [Luteal Phase +61%] [Rainy evening +18%] [Ordered comfort food 8 Tuesdays +22%]
       "The cycle phase is the single biggest contributor to tonight's prediction."

[0:38] "We use Sahha.ai to cross-reference her biomarkers —"
       → show Sahha panel: Readiness 38% · HRV 29ms · Sleep score 0.52
       "— low readiness, low HRV. Her body is confirming the phase.
        Confidence goes from 75% to 91%."

[0:50] "Now watch."
       → notification arrives on device:
       "Comfort mode: on. Dark Chocolate Maggi is ready 🍫"

[0:58] Tap → OrderConfirmSheet → Confirm.
       "Order placed."

[1:05] "This is not a generic food app.
        It's the first food prediction system that understands your body."

[1:10] "Built on Swiggy MCP for real orders, Sahha.ai for health intelligence,
        and a behavioral model trained to know you better than you know yourself."

[1:18] Done.
```

**Pre-demo setup:** Set demo user's `last_period_start` to 22 days ago. Pre-seed Sahha mock biomarkers (readiness 0.38, HRV 29ms, sleep_score 0.52). Pre-build cart for dark chocolate Maggi via Instamart MCP. Trigger notification 2 minutes before demo starts.

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

| Feature | Effort | Value | Notes |
|---|---|---|---|
| Per-user model fine-tuning | L | High | After 500+ users with 30d history |
| Wearable pairing incentive (Apple Watch/Fitbit) | S | High | Unlocks BBT, HRV — biggest accuracy jump |
| Sahha reproductive biomarkers (2026) | S | Critical | When Sahha launches `menstrual_phase` — replaces self-report, zero UI change |
| Group order prediction (couples, families) | M | Medium | Shared cycle-aware household prediction |
| WhatsApp delivery of notification | S | High | Distribution — where Indian users live |
| B2B API (restaurants pay for demand prediction) | L | High | Cycle-phase demand signals are commercially unique |
| Apple Watch complication | M | High | BBT + phase display on wrist |
| Dineout ovulatory phase suggestions | S | Medium | Use `fertile_window_start_date` from Sahha 2026 biomarkers |

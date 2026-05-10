# PRD-001: CravingsAPI — Core Product

**Version:** 1.0
**Status:** Approved
**Last Updated:** 2026-05-11

---

## Problem Statement

Indians order food on Swiggy every day, but the decision of *what to order* is made under hunger — when judgment is impaired, decision fatigue is high, and users default to the familiar or whatever is trending. The result: suboptimal choices, browse-time friction, missed meal windows, and post-order regret.

Nobody has built a product that predicts *what you'll want* and delivers the order decision to you *before* you're hungry. The behavioral data exists (order history), the context exists (weather, time, day), and the ordering infrastructure exists (Swiggy MCP). The only missing piece was a unified prediction layer.

---

## Solution

**CravingsAPI** is a behavioral food prediction engine. It learns your eating patterns across every signal it can access — order history, time, weather, day-of-week, and opt-in health data — and sends a push notification before your usual craving window with a one-tap pre-built Swiggy order ready to confirm.

The product is not an ordering app. It is a **prediction service with an ordering escape hatch**.

---

## User Personas

### Primary: Mahima, 27, Software Engineer, Bengaluru
- Orders Swiggy 5–6x/week, usually dinner
- Uses Swiggy but "spends 15 minutes deciding" every time
- Cares about nutrition vaguely, tracks nothing
- iPhone user, Apple Health installed but unused
- Pain: decision fatigue, cold food because she orders late
- Outcome: "Just tell me what to get and let me confirm. I trust my own patterns."

### Secondary: Rohan, 32, Startup founder, Mumbai
- Erratic schedule, often forgets to eat until 9 PM
- Orders Swiggy in bursts — 3 orders in 2 days, then nothing for a week
- Pain: cognitive load of decisions on top of already busy day
- Outcome: "Anything that removes friction from basic human tasks."

### Tertiary: Priya, 24, Fitness-conscious, Delhi
- Tracks macros loosely, orders "healthy options" from Swiggy
- Connects Google Fit, tracks sleep
- Pain: post-order guilt when hunger made her choose wrong
- Outcome: "I want predictions that account for how I slept and how much I moved."

---

## User Stories

### Must Have (v1)
- **US-01:** As a user, I can connect my Swiggy account so the app can learn my order patterns.
- **US-02:** As a user, I receive a push notification before my usual meal time with a predicted food item and one-tap order option.
- **US-03:** As a user, I can confirm or dismiss the pre-built order from the notification in < 3 taps.
- **US-04:** As a user, I can see my prediction history and how often the app was right.
- **US-05:** As a user, I can set quiet hours and a daily notification limit.
- **US-06:** As a user, I can choose not to connect health apps (fully optional).

### Should Have (v1)
- **US-07:** As a user, I can see *why* an item was predicted (signal explanation).
- **US-08:** As a user, I can set dietary restrictions (veg only, Jain, etc.) that filter predictions.
- **US-09:** As a user, I see a "prediction streak" showing consecutive accurate predictions.

### Nice to Have (v2)
- **US-10:** As a user, I can rate predictions ("not what I wanted") to improve future accuracy.
- **US-11:** As a user, I can share my "craving profile" (shareable card showing top predicted foods).
- **US-12:** As a user, I receive grocery predictions on Instamart for staples I'm running low on.

---

## Success Metrics

### Primary (6-month targets)
| Metric | Target |
|---|---|
| Notification → order conversion rate | ≥ 15% |
| D7 retention | ≥ 50% |
| D30 retention | ≥ 25% |
| User-reported prediction accuracy (survey) | ≥ 70% |

### Secondary
| Metric | Target |
|---|---|
| Time from notification to confirmed order | < 30 seconds |
| Daily active users / Monthly active users | ≥ 40% |
| Avg predictions correct (top-1) in first 30 days | ≥ 55% |
| NPS | ≥ 45 |

### Anti-metrics (things we don't want to optimize)
- Time spent in-app (this should be < 30s per session — it's a zero-UI product)
- Browse time (we want to eliminate browsing, not increase it)
- Number of notifications sent (more is not better; accurate is better)

---

## Non-Goals (v1)

- Restaurant discovery (Swiggy already does this)
- Nutrition tracking or calorie counting
- Social features (sharing what you're eating)
- Group ordering
- Grocery subscription management
- Dine-out reservation prediction

---

## Constraints

- Must use Swiggy MCP for all order placement (not direct Swiggy API)
- Must not store raw health data — only aggregated signals
- Must not send more than 2 push notifications per user per day without explicit user consent
- Must not place orders without explicit user confirmation (no fully-automated ordering in v1)
- Health signals are strictly opt-in — app must function fully without them

---

## Open Questions

| Question | Status | Decision |
|---|---|---|
| Should we support iMessage/WhatsApp as notification channels? | Open | Defer to v2 — FCM sufficient for v1 |
| What happens when Swiggy item is discontinued? | Resolved | Fallback to next predicted item in the same category |
| Should we support group prediction (couples)? | Deferred | Complex UX — v3 |
| Price change between prediction and order — show diff? | Resolved | Yes, always show current price on confirm screen |

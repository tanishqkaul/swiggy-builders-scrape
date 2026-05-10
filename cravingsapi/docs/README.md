# CravingsAPI — Documentation Index

> **Predict what you'll crave before you know it.**
> Behavioral food prediction engine powered by Swiggy MCP.

---

## What Is CravingsAPI?

CravingsAPI is a mobile-first application that learns your eating patterns — order history, time-of-day, weather, day-of-week, and opt-in biometric signals — and sends a push notification *before* you feel hungry, with a one-tap Swiggy order pre-loaded. The "creepy-accurate" prediction is the product.

---

## Document Map

### Strategy & Product
| File | Purpose |
|---|---|
| [prds/PRD-001-CORE.md](prds/PRD-001-CORE.md) | Overall product requirements, personas, success metrics |
| [prds/PRD-002-PREDICTION-ENGINE.md](prds/PRD-002-PREDICTION-ENGINE.md) | ML model spec, features, training pipeline |
| [prds/PRD-003-NOTIFICATIONS.md](prds/PRD-003-NOTIFICATIONS.md) | Push notification system, timing logic, copy |
| [prds/PRD-004-ONBOARDING.md](prds/PRD-004-ONBOARDING.md) | User onboarding, permissions, data consent |
| [prds/PRD-005-ONE-TAP-ORDER.md](prds/PRD-005-ONE-TAP-ORDER.md) | One-tap order flow, cart pre-fill, confirm UX |

### Engineering
| File | Purpose |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture, services, data flow diagram |
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | Full codebase map — every file, its role, and how they interact |
| [DATAMODEL.md](DATAMODEL.md) | Database schemas, entity relationships, data lifecycle |
| [INTEGRATIONS.md](INTEGRATIONS.md) | Swiggy MCP, Weather API, FCM, Health APIs — contracts & flows |
| [SECURITY.md](SECURITY.md) | Auth, encryption, PII handling, threat model |
| [TESTING.md](TESTING.md) | Unit, integration, ML validation, E2E strategy |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Infrastructure, CI/CD, environments, rollout strategy |
| [FAILURE_POLICY.md](FAILURE_POLICY.md) | Error handling, fallbacks, SLAs, on-call runbook |

### Design
| File | Purpose |
|---|---|
| [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md) | Tokens, typography, color, component library, motion |
| [UI-AUDIT.md](UI-AUDIT.md) | Screen-by-screen audit, accessibility, edge cases |

### Planning
| File | Purpose |
|---|---|
| [BUILDPLAN.md](BUILDPLAN.md) | Phased build plan, sprint breakdown, hackathon track |

---

## Tech Stack Summary

| Layer | Choice |
|---|---|
| Mobile | React Native + Expo |
| Backend API | Python / FastAPI |
| Prediction Engine | Python / scikit-learn → ONNX |
| Primary DB | PostgreSQL (Supabase) |
| Cache / Queue | Redis (Upstash) |
| Push Notifications | Firebase Cloud Messaging |
| Swiggy Data | Swiggy MCP (Food + Instamart + Dineout) |
| Weather | OpenWeatherMap API |
| Health Signals | Apple HealthKit / Google Fit (opt-in) |
| Auth | Supabase Auth + Swiggy OAuth2 |
| Hosting | Railway (API) + Vercel (web) + Expo EAS (mobile) |

---

## Core User Flow

```
User installs app
  → grants Swiggy OAuth (order history read)
  → grants location + notification permission
  → optionally connects Apple Health / Google Fit

Background engine (every 15 min):
  → pulls weather, time, day, behavioral signals
  → runs prediction model
  → if confidence > threshold → schedules push notif

User receives push: "You'll probably want Maggi around 8 PM 🍜 — tap to pre-order"
  → one tap → pre-filled Swiggy cart
  → user confirms → order placed via Swiggy MCP
```

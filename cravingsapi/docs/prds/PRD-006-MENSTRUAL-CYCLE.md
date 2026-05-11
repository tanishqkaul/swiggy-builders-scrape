# PRD-006: Menstrual Cycle Intelligence

**Version:** 1.0
**Status:** Core Feature — v1
**Sensitivity:** Ultra-sensitive personal health data. Review SECURITY.md §Menstrual Data before any changes.

---

## Why This Is the Product's Biggest Differentiator

Food cravings across the menstrual cycle are not random — they are physiologically driven and highly predictable. Every phase produces distinct hormonal shifts that directly affect appetite, texture preferences, caloric need, and emotional comfort food patterns:

| Phase | Days (28-day cycle) | Dominant Hormones | Craving Profile |
|---|---|---|---|
| **Menstrual** | 1–5 | Prostaglandins, low estrogen/progesterone | Warm comfort food, iron-rich (dal, meat), chocolate, anti-cramp foods |
| **Follicular** | 6–13 | Rising estrogen | Lighter meals, fresh/salad-type, more adventurous, lower appetite |
| **Ovulatory** | 14–16 | LH surge, estrogen peak | Social eating, restaurant meals, higher appetite, protein |
| **Luteal** | 17–28 | High progesterone, falling estrogen | Carbs, chocolate, salty snacks, comfort food — peak craving intensity |

**The luteal phase alone (days 17–28) accounts for the vast majority of "I don't know why I want this" craving moments.** No food prediction system currently accounts for this.

This data, combined with Sahha.ai's biomarker stream (HRV, resting HR, sleep quality, body temperature), creates a prediction system that is:
- More accurate for female users than any existing food prediction tool
- Deeply personal — impossible to replicate without both cycle tracking + order history
- Emotionally resonant: users will feel *understood*

---

## Integration with Sahha.ai

### Why Sahha Over Raw HealthKit/Fit

Sahha provides:
1. **Processed biomarkers** — normalized, cleaned, cross-platform. Same API for iOS (HealthKit) and Android (Health Connect).
2. **Readiness and Mental Wellbeing scores** — not available from raw HealthKit at all. These are Sahha's computed intelligence.
3. **Reproductive biomarkers coming 2026** — `menstrual_phase`, `menstrual_cycle_day_number`, `menstrual_phase_days_to_next_phase` — Sahha will compute phase natively from HealthKit cycle tracking data. Our architecture is designed to plug this in without breaking changes.
4. **`body_temperature_basal`** — BBT (wearable-required) is the clinical gold standard for phase detection. A 0.2–0.5°C rise at ovulation is measurable and reliable.

**Current state (pre-2026):** Phase computed from user self-report (period start date) + day counting. Sahha confirms and amplifies the phase signal via biomarkers.
**2026+ state:** Sahha's `menstrual_phase` biomarker replaces the self-report entirely. User just connects Apple Health (where they may already log their cycle in Cycle Tracking) and Sahha reads it. Zero extra UI.

### Sahha Signals Used (Exact Field Names from Data Dictionary)

**No wearable required** — available to all users with Sahha connected:

| Sahha Field | What It Provides | How Used for Cycles |
|---|---|---|
| `score.sleep` | 0–1 sleep quality composite | Low score in luteal → comfort food prediction boost |
| `score.readiness` | 0–1 daily recovery | Very low (< 0.35) in menstrual → warmth/comfort prediction |
| `score.mental_wellbeing` | 0–1 mental wellness | Low in late luteal (PMS) → emotional eating signal |
| `score.activity` | 0–1 physical activity | Low in menstrual → calorie-dense, minimal-prep meals |
| `biomarker.sleep_duration` | minutes/night | Short sleep in luteal → craving intensity amplifier |
| `biomarker.sleep_regularity` | 0–1 index (weekly) | Disrupted regularity → phase transition indicator |
| `biomarker.sleep_debt` | hours (weekly) | High debt in luteal → comfort food override |
| `biomarker.steps` | daily count | Low steps + luteal → predict delivery over dineout |
| `biomarker.activity_sedentary_duration` | minutes/day | High sedentary in menstrual → warm delivery meal |

**Wearable required** — high-value when available, gracefully absent when not:

| Sahha Field | Wearable? | Cycle Significance |
|---|---|---|
| `biomarker.heart_rate_resting` | **Yes** | +2–5 bpm in luteal is a reliable phase marker |
| `biomarker.heart_rate_variability_sdnn` | **Yes** | Low HRV in late luteal/menstrual; peaks at ovulation |
| `biomarker.heart_rate_variability_rmssd` | **Yes** | Complementary HRV — averaged with SDNN |
| `biomarker.body_temperature_basal` | **Yes** | **BBT gold standard**: rises 0.2–0.5°C at ovulation, stays elevated through luteal, drops at period onset |
| `biomarker.skin_temperature_sleep` | **Yes** | Detects ovulation temperature shift (non-oral BBT proxy) |
| `biomarker.sleep_efficiency` | **Yes** | Degrades significantly in late luteal |
| `biomarker.sleep_interruptions` | **Yes** | Spikes in late luteal before period |
| `biomarker.respiratory_rate_sleep` | **Yes** | Elevated in luteal phase |

**Coming 2026 — Reproductive Biomarkers (will be primary cycle data source):**

| Sahha Field | Periodicity | What Replaces |
|---|---|---|
| `biomarker.menstrual_phase` | weekly | Our computed phase from day counting |
| `biomarker.menstrual_cycle_day_number` | **daily** | Our `cycle_day` column |
| `biomarker.menstrual_phase_days_to_next_phase` | **daily** | Our `days_until_period` estimate |
| `biomarker.menstrual_cycle_start_date` | monthly | User's manual period log |
| `biomarker.menstruation_period_start_date` | monthly | `cycle_profiles.last_period_start` |
| `biomarker.fertile_window_start_date` | monthly | (New signal — enables Dineout ovulatory suggestions) |

---

## User Flow: Cycle Setup

### First-Time Setup (after Sahha connected)
```
[After Sahha connection in onboarding]
  ↓
"One more thing — this unlocks our most accurate predictions."

"When did your last period start?"
[Date picker — scrollable, default: today]

[  Set period date  ]   [  Skip  ]
```

**If skipped:** Cycle feature disabled until user adds it later from Settings. App works normally without it.

**If set:** `cycle_profiles` record created. Cycle phase computed. Prediction engine immediately upgrades.

### Ongoing Tracking
- **Monthly reminder** (push notification, quiet tone): "Period due soon? Update your cycle date." — sent 25 days after last logged start date
- **In-app logging:** Settings → Cycle Tracking → "Log period start" button
- **Smart detection:** If Sahha readiness + HRV + sleep scores all drop sharply in pattern → system suggests: "Looks like your period might have started. Update cycle date?" (never stated as fact — always a suggestion)

---

## Phase Detection Algorithm

```python
# services/cycle_service.py

PHASE_MAP = {
    range(1, 6): "menstrual",      # days 1–5
    range(6, 14): "follicular",    # days 6–13
    range(14, 17): "ovulatory",    # days 14–16
    range(17, 100): "luteal",      # days 17–end (up to next period)
}

def get_current_phase(profile: CycleProfile, today: date) -> CyclePhase:
    days_since_start = (today - profile.last_period_start).days + 1
    cycle_length = profile.avg_cycle_length or 28

    if days_since_start > cycle_length + 5:
        # Period overdue — likely luteal still, flag for user reminder
        return CyclePhase(phase="luteal", day=days_since_start, overdue=True)

    for day_range, phase_name in PHASE_MAP.items():
        if days_since_start in day_range:
            return CyclePhase(
                phase=phase_name,
                day=days_since_start,
                cycle_length=cycle_length,
                days_until_next=max(0, cycle_length - days_since_start)
            )

def get_sahha_phase_confidence(biomarkers: SahhaBiomarkers, expected_phase: str) -> float:
    """Cross-reference expected phase with Sahha biomarker patterns."""
    confidence = 1.0
    if expected_phase == "luteal":
        # Low readiness, elevated RHR, low HRV are characteristic
        if biomarkers.readiness_score < 0.5: confidence += 0.15
        if biomarkers.hrv_sdnn < 35: confidence += 0.10
        if biomarkers.sleep_score < 0.6: confidence += 0.10
    elif expected_phase == "menstrual":
        if biomarkers.readiness_score < 0.4: confidence += 0.20
        if biomarkers.mental_wellbeing_score < 0.5: confidence += 0.10
    return min(confidence, 1.5)  # multiplier on base prediction confidence
```

---

## Phase-Specific Craving Overrides

When cycle phase is known, the prediction engine applies **phase overrides** — biases applied to the base ML prediction:

### Menstrual Phase (Days 1–5)
```python
MENSTRUAL_BOOSTS = {
    "categories": ["biryani", "dal_rice", "khichdi", "soup", "hot_chocolate", "pasta"],
    "attributes": ["warm", "comfort", "iron_rich", "easy_to_eat"],
    "avoid": ["salad", "cold_foods", "heavy_fried"],
    "temperature_preference": "warm",
    "boost_factor": 1.4  # 40% boost to matching categories
}
```
**Copy in notification:** "Warm and comforting tonight 🫂 — [item] is ready."

### Follicular Phase (Days 6–13)
```python
FOLLICULAR_BOOSTS = {
    "categories": ["salad", "grilled", "wraps", "smoothie_bowl", "sushi"],
    "attributes": ["fresh", "light", "protein"],
    "boost_factor": 1.2
}
```
**Copy:** "Feeling fresh today? [item] matches your energy."

### Ovulatory Phase (Days 14–16)
```python
OVULATORY_BOOSTS = {
    "categories": ["restaurant_meal", "dineout", "shared_platters", "grilled_protein"],
    "attributes": ["social", "high_protein"],
    "boost_factor": 1.1,
    "dineout_suggestion": True  # Can trigger Dineout MCP recommendation
}
```
**Copy:** "Peak energy tonight — how about [restaurant] for dinner?"

### Luteal Phase (Days 17–28)
```python
LUTEAL_BOOSTS = {
    "categories": ["chocolate", "biryani", "pizza", "pasta", "maggi", "chips"],
    "attributes": ["carbs", "comfort", "sweet", "salty"],
    "avoid": ["salad", "light"],
    "boost_factor": 1.6,  # Strongest override — luteal cravings are most intense
    "calorie_prediction_boost": 1.25  # User will order higher-calorie items
}
```
**Copy variants:**
- "Late luteal hit different. [item] is ready when you are. 🍫"
- "Your body knows what it wants. We just listened."
- "Comfort mode: on. [item] incoming."

---

## Sahha API Integration

### Authentication Flow
```
Backend creates Sahha Profile for new user:
POST https://api.sahha.ai/oauth/profile/register
{
  "externalId": "cravingsapi_user_{user_id}",
  "demographics": {
    "gender": "female",
    "age": user.age  // optional, improves accuracy
  }
}
→ returns profileToken

Mobile SDK authenticates with profileToken:
Sahha.authenticate(appId, appSecret, externalId, profileToken)
→ SDK starts passive data collection (no user action required)
```

### Biomarker Fetch (Backend, every 15 min per cycle-enabled user)
```python
# integrations/sahha.py

async def get_biomarkers(external_id: str) -> SahhaBiomarkers:
    today = date.today().isoformat()
    headers = {"Authorization": f"account {SAHHA_ACCOUNT_TOKEN}"}

    # Fetch multiple biomarkers in parallel
    results = await asyncio.gather(
        get(f"/profile/biomarker?externalId={external_id}&type=heart_rate_resting&startDateTime={today}"),
        get(f"/profile/biomarker?externalId={external_id}&type=heart_rate_variability_sdnn&startDateTime={today}"),
        get(f"/profile/score?externalId={external_id}&types=sleep,readiness,mental_wellbeing&startDateTime={today}"),
    )
    return SahhaBiomarkers.parse(results)
```

### Webhook (Real-time biomarker updates)
```
Sahha → POST https://api.cravingsapi.app/webhooks/sahha
Headers: X-Signature: HMAC-SHA256, X-External-Id: "cravingsapi_user_{id}", X-Event-Type: "BiomarkerCreatedIntegrationEvent"

→ verify HMAC signature
→ extract user_id from external_id
→ update cached biomarkers in Redis
→ if biomarker suggests phase shift (sharp drop in readiness): trigger phase suggestion
```

---

## UI: Cycle Tracking Screens

### Cycle Phase Card (Home Screen — above PredictionCard)
```
┌──────────────────────────────────────────────────┐
│  🌙 Luteal Phase · Day 22                         │
│  [━━━━━━━━━━━━━━━━░░░░░░]  6 days until period    │
│  "Comfort food cravings are totally normal now."  │
└──────────────────────────────────────────────────┘
```
Phase colors:
- Menstrual: warm red `#e07070`
- Follicular: fresh teal `#70c8b8`
- Ovulatory: golden amber `#f0b840`
- Luteal: deep purple `#9070c0`

### Phase Detail Screen (tap the card)
```
[Phase name — large]
[Day X of ~28-day cycle]
[Hormone bar chart — estrogen, progesterone arcs]
[What to expect this phase:]
  • Cravings: chocolate, carbs, comfort food
  • Energy: lower than usual
  • Sleep: may be disrupted
[Your Sahha readiness today: 42%]
[Your HRV today: 32ms (lower than your usual 48ms)]
[How this affects your predictions ↓]
  Showing more warm, comfort foods today.
```

### Log Period Screen (Settings → Cycle)
```
"When did your period start?"
[Calendar picker — scrollable]
[  Save  ]

Past entries:
  April 13 → avg cycle: 27 days
  March 17
  February 18
```

---

## Consent & Privacy (Non-Negotiable)

- Cycle tracking is **opt-in at every layer**: Sahha connection + cycle date logging are both separately opt-in
- Cycle data is stored in `cycle_profiles` table with column-level encryption (separate from regular user encryption)
- The word "menstrual" or "period" never appears in push notification copy — copy uses "cycle" only on explicit settings screens
- **No cycle data shared with any third party** — not even Swiggy MCP calls reference cycle phase
- Users can delete cycle data independently from account deletion: Settings → Cycle Tracking → "Delete all cycle data"
- If user deletes cycle data: `cycle_profiles` row hard-deleted within 24 hours (no soft delete)
- Sahha profile data: user can trigger `DELETE /profile` on Sahha via our backend at any time

---

## Success Metrics (Cycle Feature Specifically)

| Metric | Target |
|---|---|
| Opt-in rate among female users | ≥ 40% |
| Prediction accuracy (top-1) with cycle data vs without | +12 percentage points |
| Notification → order rate for luteal phase users | ≥ 22% (vs 15% baseline) |
| User-reported "this felt right" rating | ≥ 4.3/5 on cycle-days |
| Feature retention (still using cycle tracking at D30) | ≥ 60% |

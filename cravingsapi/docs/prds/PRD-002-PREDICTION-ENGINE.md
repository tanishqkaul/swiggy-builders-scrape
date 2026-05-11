# PRD-002: Prediction Engine

**Version:** 1.0
**Status:** Approved

---

## Goal

Define the exact behavior of the prediction engine: what signals it uses, how they are combined, what the model outputs, how confidence is computed, and when fallbacks are triggered.

---

## Inputs: Signal Taxonomy

### Tier 1 — High Signal (always available, highest weight)
| Signal | Source | Description |
|---|---|---|
| `hour_sin / hour_cos` | System time | Cyclic encoding of current hour |
| `dow_sin / dow_cos` | System time | Cyclic encoding of day of week |
| `is_weekend` | System time | Saturday or Sunday |
| `orders_last_7d` | Swiggy MCP | Order frequency in past week |
| `last_order_hrs_ago` | Swiggy MCP | Hours since most recent order |
| `top_cuisine_vector` | Swiggy MCP | 10-dim vector: fraction of orders per cuisine type |
| `top_item_vector` | Swiggy MCP | 20-dim one-hot: user's top 20 items by frequency |
| `avg_order_hour` | Swiggy MCP | Mean hour of day across all orders |
| `std_order_hour` | Swiggy MCP | Std deviation of order hours (routine vs erratic) |

### Tier 1B — Menstrual Cycle Signals (opt-in, **highest single-feature impact for female users**)

These are the most powerful features in the model when available. A user in the luteal phase craves carbs/comfort food at a rate empirically far above their baseline — this single feature group can shift predicted category with confidence ≥ 0.80 even without any other signals.

| Signal | Source | Description |
|---|---|---|
| `cycle_phase_OHE` | `cycle_profiles` | 4-dim: [menstrual, follicular, ovulatory, luteal] |
| `cycle_day` | `cycle_profiles` | Day number within current cycle (1–35) |
| `cycle_day_sin / cycle_day_cos` | Computed | Cyclic encoding to capture periodicity |
| `days_until_period` | `cycle_profiles` | Countdown to next expected period (key for late luteal) |
| `cycle_has_data` | `cycle_profiles` | 0/1 indicator — model knows when to use these features |
| `phase_sahha_confirmed` | Sahha + cycle | 1 if Sahha biomarkers match expected phase pattern, 0 otherwise |
| `phase_confidence_multiplier` | Sahha + cycle | Float 0.8–1.5: how strongly Sahha confirms this phase |

**Research basis for cycle × food craving link:**
- Luteal phase: progesterone drives carbohydrate and serotonin-precursor cravings (chocolate, rice, pasta). Average caloric intake increases ~200 kcal/day.
- Menstrual phase: prostaglandins cause comfort food seeking (warm, easy-to-digest foods); iron loss increases appetite for iron-rich items.
- Follicular phase: rising estrogen suppresses appetite relative to baseline; users are more adventurous.
- Ovulatory: LH surge + estrogen peak → protein preference, higher social food behavior.

### Tier 2 — Medium Signal (usually available, moderate weight)
| Signal | Source | Description |
|---|---|---|
| `temp_celsius` | OpenWeatherMap | Current temperature |
| `feels_like` | OpenWeatherMap | Apparent temperature |
| `is_raining` | OpenWeatherMap | Boolean: rain/drizzle in current conditions |
| `weather_code_OHE` | OpenWeatherMap | 8-dim OHE of OWM weather category |
| `humidity` | OpenWeatherMap | Relative humidity % |
| `days_since_payday` | Computed | Estimated days since last salary (1st/15th month) |

### Tier 3 — Sahha Biomarker Signals (opt-in via Sahha SDK, cross-platform)

Sahha provides processed biomarkers from Apple HealthKit (iOS) and Google Health Connect (Android) — same API, no platform-specific code on our side. Signals are split by wearable requirement to accurately reflect data availability per user.

**Important:** `heart_rate_resting` and `heart_rate_variability_sdnn` **require a wearable** per Sahha's Data Dictionary. They are powerful cycle signals but cannot be assumed available. The feature vector uses `sahha_has_wearable` to gate these inputs.

#### No Wearable Required (all Sahha users)

| Signal (feature name) | Sahha Field | Unit | Cycle Interaction |
|---|---|---|---|
| `sahha_sleep_score` | `score.sleep` | 0–1 | Low → comfort food; amplifies luteal signal |
| `sahha_readiness_score` | `score.readiness` | 0–1 | Low (< 0.35) confirms menstrual phase |
| `sahha_mental_wellbeing` | `score.mental_wellbeing` | 0–1 | Low → emotional eating; drops sharply in late luteal |
| `sahha_activity_score` | `score.activity` | 0–1 | Low → calorie-dense delivery prediction |
| `sahha_sleep_duration_norm` | `biomarker.sleep_duration` | minutes (normalized) | Short sleep in luteal → craving intensity boost |
| `sahha_sleep_regularity` | `biomarker.sleep_regularity` | 0–1 index (weekly) | Disrupted in luteal/menstrual |
| `sahha_sleep_debt_norm` | `biomarker.sleep_debt` | hours (normalized) | High debt → comfort food override |
| `sahha_steps_norm` | `biomarker.steps` | count (normalized) | Low steps + luteal → predict delivery > dineout |
| `sahha_sedentary_norm` | `biomarker.activity_sedentary_duration` | minutes (normalized) | High sedentary in menstrual → warm meal |

#### Wearable Required (used when `sahha_has_wearable=1`, zeroed otherwise)

| Signal (feature name) | Sahha Field | Unit | Cycle Significance |
|---|---|---|---|
| `sahha_hrv_sdnn_norm` | `biomarker.heart_rate_variability_sdnn` | ms (normalized) | Low → late luteal/menstrual; peaks at ovulation |
| `sahha_hrv_rmssd_norm` | `biomarker.heart_rate_variability_rmssd` | ms (normalized) | Complementary to SDNN |
| `sahha_resting_hr_norm` | `biomarker.heart_rate_resting` | bpm (normalized) | +2–5 bpm in luteal — physiological phase marker |
| `sahha_sleep_efficiency` | `biomarker.sleep_efficiency` | ratio 0–1 | Degrades in late luteal |
| `sahha_bbt_delta` | `biomarker.body_temperature_basal` | celsius delta from baseline | **Strongest wearable signal**: +0.2–0.5°C spike = ovulation confirmed; elevated = luteal |
| `sahha_skin_temp_sleep` | `biomarker.skin_temperature_sleep` | celsius (normalized) | Ovulation temperature proxy |

#### Meta Flags

| Signal | Description |
|---|---|
| `sahha_has_data` | 1 if Sahha connected and returned data today, else 0 |
| `sahha_has_wearable` | 1 if wearable biomarkers returned non-null today, else 0 |
| `sahha_data_age_hours` | Hours since last successful Sahha fetch (freshness indicator) |

**2026 upgrade:** When Sahha releases reproductive biomarkers, `cycle_phase_OHE` and `cycle_day` will be sourced from `biomarker.menstrual_phase` and `biomarker.menstrual_cycle_day_number` respectively — moving them from user self-report to Tier 3 (Sahha-provided) without any feature vector dimensionality change.

---

## Model Architecture

### Primary: XGBoost Classifier
- **Task:** Multi-class classification (top-N item prediction)
- **Target:** Item category (not exact item ID — prevents cold-start on new items)
- **Output:** Probability distribution over 15 cuisine/category classes
- **Post-processing:** Top predicted category → query Swiggy MCP for user's most-ordered item in that category at current location → return as prediction

**Why XGBoost over neural net:**
- Fast inference (< 5ms on CPU)
- Handles sparse/mixed feature types well (OHE + continuous)
- Exportable to ONNX
- Interpretable (SHAP values for "why this prediction" UI)
- Doesn't require GPU — can run on any Railway pod

### Fallback: Rule-Based Heuristic
Triggers when:
- ONNX model fails to load
- Inference error occurs
- Model confidence < 0.35 (model unsure → rule-based is safer)
- User has < 10 lifetime orders (not enough data for ML)

```python
def rule_based_predict(order_history, current_hour, current_dow):
    # Filter orders to same hour bucket (±2h) and same weekday
    matching = [o for o in order_history
                if abs(o.hour - current_hour) <= 2
                and o.weekday == current_dow]
    if not matching:
        matching = order_history  # broaden
    # Return most-ordered item in matched window
    counter = Counter(o.item_category for o in matching)
    top_category = counter.most_common(1)[0][0]
    return top_category, confidence=0.40
```

---

## Feature Vector (108 dimensions)

| Feature Group | Dims | Features | Wearable Needed? |
|---|---|---|---|
| Time | 6 | hour_sin, hour_cos, dow_sin, dow_cos, is_weekend, days_since_payday | No |
| Weather | 12 | temp_celsius, feels_like, humidity, weather_code_OHE (8-dim), is_raining | No |
| Order history | 6 | orders_last_7d, orders_last_30d, avg_order_value, last_order_hrs_ago, order_streak, avg_days_between_orders | No |
| Item preferences | 30 | top_10_category_OHE, top_20_item_OHE | No |
| Meal timing | 4 | avg_lunch_hour, avg_dinner_hour, std_lunch_hour, std_dinner_hour | No |
| **Menstrual cycle** | **9** | **cycle_phase_OHE (4), cycle_day, cycle_day_sin, cycle_day_cos, days_until_period, cycle_has_data** | No (self-report) |
| **Sahha — no wearable** | **11** | **sleep_score, readiness_score, mental_wellbeing, activity_score, sleep_duration_norm, sleep_regularity, sleep_debt_norm, steps_norm, sedentary_norm, sahha_has_data, sahha_data_age_hours** | No |
| **Sahha — wearable** | **6** | **hrv_sdnn_norm, hrv_rmssd_norm, resting_hr_norm, sleep_efficiency, bbt_delta, skin_temp_sleep** | **Yes** |
| Sahha meta | **3** | **sahha_has_wearable, phase_sahha_confirmed, phase_confidence_multiplier** | No |
| Archetype encodings | **7** | **sleep_pattern_OHE (4), activity_level_OHE (3)** | No |
| Streak & meta | 14 | consecutive_days_used_app, prediction_accuracy_last_10, cycle_data_age_days + (11 cuisine/phase interaction features) | No |

**Data availability tiers:**
- All users: 82-dim (no Sahha, no wearable, no cycle) → baseline model
- Sahha connected, no wearable: +20 dims → ~+8 pp accuracy
- Sahha + wearable: +9 more dims → ~+5 pp additional  
- Any of above + cycle: +9 cycle dims → **+12 pp for female users in luteal**
- Full stack (all dims): estimated **+25 pp vs baseline** for luteal-phase female users with wearable

---

## Phase Override Layer

Applied **after** ML inference. The ML model outputs a category distribution. If cycle phase is known, a phase override multiplier is applied before selecting the final category:

```python
PHASE_BOOSTS = {
    "menstrual": {
        "biryani": 1.4, "dal_rice": 1.5, "khichdi": 1.6, "soup": 1.5,
        "hot_chocolate": 1.4, "maggi": 1.4,
        "salad": 0.5, "cold_beverages": 0.4,  # suppress
    },
    "follicular": {
        "salad": 1.3, "wraps": 1.2, "grilled": 1.2, "smoothie": 1.2,
        "biryani": 0.85,  # slight suppress
    },
    "ovulatory": {
        "grilled_protein": 1.3, "restaurant_meal": 1.2, "shared_platter": 1.2,
    },
    "luteal": {
        "chocolate": 1.7, "biryani": 1.5, "pizza": 1.5, "pasta": 1.4,
        "maggi": 1.6, "chips_snacks": 1.5,
        "salad": 0.4,  # strong suppress
    },
}

def apply_phase_override(category_probs: dict, phase: str, confidence_multiplier: float) -> dict:
    boosts = PHASE_BOOSTS.get(phase, {})
    adjusted = {cat: prob * boosts.get(cat, 1.0) for cat, prob in category_probs.items()}
    # Re-normalize
    total = sum(adjusted.values())
    normalized = {cat: v / total for cat, v in adjusted.items()}
    # Scale confidence up/down based on Sahha phase confirmation
    return normalized, confidence_multiplier
```

The Sahha `phase_confidence_multiplier` (0.8–1.5) scales the final output confidence — if Sahha biomarkers strongly confirm we're in the expected phase, confidence goes up; if they contradict (e.g., user logged luteal but HRV and readiness are both high), confidence is dampened.

---

## Output Schema

```python
@dataclass
class PredictionResult:
    item_id: str              # Swiggy item ID (fetched post-prediction)
    item_name: str            # Display name
    item_image_url: str       # CDN URL for display
    restaurant_id: str        # Nearest Swiggy restaurant carrying this item
    restaurant_name: str
    category: str             # 'biryani', 'pizza', 'south_indian', etc.
    confidence: float         # 0.0–1.0, after Sahha phase multiplier applied
    window_start: time        # Predicted craving window start
    window_end: time          # Predicted craving window end
    cycle_phase: str | None   # 'menstrual'|'follicular'|'ovulatory'|'luteal'|None
    cycle_day: int | None     # Day in cycle, or None if not tracking
    phase_override_applied: bool  # True if phase boosts changed the category
    signal_contributions: dict  # SHAP values + phase boost amounts for "why" UI
    fallback_used: bool
    model_version: str
```

---

## Confidence Calibration

Raw XGBoost probabilities are overconfident. Post-training calibration applied via Platt scaling (sigmoid calibration) on a held-out calibration set.

**Target:** Brier score < 0.15 on holdout. Brier = mean squared error of probability predictions.

**User-visible confidence tiers:**
| Confidence | Display | Notification copy |
|---|---|---|
| ≥ 0.80 | "We're {X}% sure" | "We know what you want 👀" |
| 0.60–0.79 | "Feeling like {item}?" | "You usually want this now." |
| 0.55–0.59 | "Our best guess:" | "Maybe? Your call." |
| < 0.55 | Not shown | No notification sent |

---

## Craving Window Computation

The model also predicts *when* the craving will peak, not just *what* it will be.

```python
# From order history: compute mean and std of order hours per item category
mean_hour = np.mean([o.hour for o in history if o.category == predicted_category])
std_hour = np.std([o.hour for o in history if o.category == predicted_category])

window_start = mean_hour - max(0.5, std_hour)  # at least 30-min window
window_end = mean_hour + max(0.5, std_hour)
```

Notification fires at `window_start - 45 minutes`. Pre-built cart TTL set to `window_end + 30 minutes`.

---

## Training Data

### Structure
- Each row: one user's signal snapshot at time T + label = item they ordered within 3 hours
- Negative samples: signal snapshots where no order followed within 3 hours
- Balance: 1:2 positive:negative ratio

### Data sources (hackathon)
- Synthetic data generated by `ml/training/dataset_builder.py` with realistic priors
- 5,000 synthetic users × 90 days of behavioral data
- After Swiggy MCP approval: real anonymized data (future)

### Retraining schedule
- Weekly offline retrain on past 180 days of data
- Auto-triggered if prediction coverage drops below 80% or accuracy drops 10%
- Manual approval before production deploy

---

## Explainability (SHAP)

Every prediction includes top-3 signal contributions for the "Why this?" screen:

```python
import shap
explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(feature_vector)

# Top 3 contributing features:
# [("Rainy weather", +0.18), ("Thursday", +0.14), ("Ordered biryani 6x Thursdays", +0.31)]
```

These map to human-readable copy in the app's signal explanation view.

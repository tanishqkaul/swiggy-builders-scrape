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

### Tier 2 — Medium Signal (usually available, moderate weight)
| Signal | Source | Description |
|---|---|---|
| `temp_celsius` | OpenWeatherMap | Current temperature |
| `feels_like` | OpenWeatherMap | Apparent temperature |
| `is_raining` | OpenWeatherMap | Boolean: rain/drizzle in current conditions |
| `weather_code_OHE` | OpenWeatherMap | 8-dim OHE of OWM weather category |
| `humidity` | OpenWeatherMap | Relative humidity % |
| `days_since_payday` | Computed | Estimated days since last salary (1st/15th month) |

### Tier 3 — Low Signal (opt-in, small weight but measurable impact)
| Signal | Source | Description |
|---|---|---|
| `sleep_hours_last_night` | HealthKit / Fit | Total sleep hours last night (0 if not connected) |
| `steps_today` | HealthKit / Fit | Step count so far today (0 if not connected) |

**Note on sleep signal:** Empirically, sleep < 6 hours correlates with comfort food orders (biryani, pizza over salads). This is a meaningful predictor, hence the opt-in push.

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
    confidence: float         # 0.0 – 1.0
    window_start: time        # Predicted craving window start
    window_end: time          # Predicted craving window end
    signal_contributions: dict  # SHAP values for "why" explanation
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

# PRD-003: Notification System

**Version:** 1.0
**Status:** Approved

---

## Goal

Design the complete notification system: timing logic, copy templates, delivery mechanics, user controls, and feedback loop. The notification is the primary UI of CravingsAPI. It must feel useful, not spammy.

---

## Notification Lifecycle

```
Prediction produced (confidence ≥ threshold)
  → Compute fire_time = window_start - 45 min
  → Check quiet hours: is fire_time in quiet window?
     → Yes: defer to quiet_hours_end + 15 min
  → Check daily cap: has user already received max_notifs_per_day today?
     → Yes: skip. Log "capped".
  → Pre-build Swiggy cart, store in Redis with 90-min TTL
  → Enqueue FCM job for fire_time
  → At fire_time: send FCM
  → Track: sent event in notification_events
```

---

## Copy Templates

All notification copy is personalized at render time. Variables in `{}` are interpolated.

### Template: High Confidence (≥ 0.80)
```
Title: "We know what you want 👀"
Body: "{item_name} from {restaurant_name} — tap to pre-order"
```

### Template: Medium Confidence (0.65–0.79)
```
Title: "Feeling like {item_name}?"
Body: "You usually order this on {weekday} evenings. One tap away."
```

### Template: Weather-Driven
```
Title: "Cold + hungry = {item_name}"
Body: "It's {temp}°C outside. {item_name} from {restaurant_name} is ready."
```
*(Triggered when `is_raining=True` or `feels_like < 18°C` is the top SHAP contributor)*

### Template: Weekday Pattern
```
Title: "{weekday_greeting} already?"
Body: "You usually want {item_name} around {window_start}. Pre-order now."
weekday_greeting: "Friday!" | "Weekend vibes" | "Midweek mood"
```

### Template: Post-Streak
```
Title: "5 for 5 🔥"
Body: "CravingsAPI has nailed your last 5 cravings. Tonight: {item_name}."
```
*(Triggered on 5+ consecutive correct predictions)*

### Template: Fallback (rule-based, lower confidence)
```
Title: "Our best guess tonight:"
Body: "{item_name}. Not sure? Open the app to browse."
```

---

## Timing Rules

| Rule | Value | Rationale |
|---|---|---|
| Lead time before craving window | 45 minutes | Enough time to confirm + prep delivery |
| Minimum lead time | 20 minutes | Below this, skip until next cycle |
| Max notifications per day | 2 (default, user-configurable to 1) | Respect cognitive budget |
| Quiet hours (default) | 22:00–07:00 | Sleep time |
| Defer window | quiet_hours_end + 15 min | Not the exact wakeup moment |
| Prediction cycle interval | 15 minutes | Balance freshness vs compute cost |
| Minimum time between notifications | 3 hours | No double-pinging on same day |

---

## Per-User Threshold Adaptation

Each user's confidence threshold (`user_preferences.confidence_threshold`) is adapted over time:

```python
def adapt_threshold(user_id: str, window_days: int = 30):
    events = get_notification_events(user_id, days=window_days)
    order_rate = count(events, type='ordered') / count(events, type='sent')
    dismiss_rate = count(events, type='dismissed') / count(events, type='sent')

    if order_rate < 0.10 and dismiss_rate > 0.50:
        # User dismissing a lot — raise threshold (send less, but higher quality)
        new_threshold = min(current_threshold + 0.05, 0.90)
    elif order_rate > 0.30:
        # User converting well — can lower threshold slightly (more notifications)
        new_threshold = max(current_threshold - 0.02, 0.45)
    # else: no change
```

Runs weekly per user. Changes are subtle — maximum 0.05 shift per week.

---

## Deep Link Spec

Every notification includes a `data` payload with:
```json
{
  "prediction_id": "pred_01HX...",
  "cart_id": "cart:pred_01HX...",
  "deep_link": "cravingsapi://confirm/pred_01HX..."
}
```

On notification tap:
- App is in foreground: `Linking` event fires → navigate to `confirm-order.tsx` with `prediction_id` param
- App is in background: `getInitialURL()` on mount → same navigation
- App is killed: `getInitialURL()` on cold launch → same navigation

If notification is > 4 hours old (cart expired): ignore deep link, navigate to History screen with the expired prediction highlighted.

---

## Notification Channels (Android)

```java
// Channel: predictions (high priority)
NotificationChannel channel = new NotificationChannel(
    "predictions",
    "Craving Predictions",
    NotificationManager.IMPORTANCE_HIGH
);
channel.setDescription("Your personalized food predictions");
channel.enableVibration(true);
channel.setVibrationPattern(new long[]{0, 250, 100, 250});
```

---

## Event Tracking

Every notification interaction is recorded in `notification_events`:

| Event | When Recorded |
|---|---|
| `sent` | FCM send() call succeeds |
| `opened` | User taps notification (deep link fires) |
| `dismissed` | User swipes away notification (FCM dismiss event or user taps "Not now" in app) |
| `ordered` | `POST /orders/confirm` succeeds for this prediction |
| `cart_expired` | Cart TTL elapsed with no order |

These feed into:
1. Per-user threshold adaptation (above)
2. Admin dashboard conversion funnel
3. Weekly ML retraining labels ("did user order after this prediction?")

---

## Anti-Spam Safeguards

- Hard cap: never more than 3 notifications in any 24-hour period, regardless of settings
- If user dismisses 5 consecutive notifications: pause all notifications for 24 hours and show in-app nudge "Adjust your prediction settings?"
- If FCM token marked as invalid: immediately stop all notifications for that user, do not retry
- Notification text never mentions pricing or promotions (not a marketing channel)
- No notifications about items the user has never ordered from that cuisine category (cold predictions disabled)

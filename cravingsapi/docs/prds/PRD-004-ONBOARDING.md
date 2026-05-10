# PRD-004: User Onboarding

**Version:** 1.0
**Status:** Approved

---

## Goal

Get users from install to first prediction in under 3 minutes. Collect minimum necessary permissions. Make every permission ask feel worth it.

---

## Onboarding Flow (4 steps)

```
[Step 1: Splash/Hook]
  → [Step 2: Location]
  → [Step 3: Swiggy Connect]
  → [Step 4: Health (optional)]
  → [Home screen]
```

Total steps: 4. Total required taps: ~8. Target completion time: < 2.5 minutes.

---

## Step 1: Splash / Hook Screen

**Goal:** Make the user emotionally understand the product in 10 seconds. No walls of text.

**Content:**
```
[Animated illustration: phone buzzing, food appearing, tick]

Large text: "You'll know what you want
             before you're hungry."

Small text: "CravingsAPI learns your patterns and
             sends you a one-tap order at the right moment."

[Get started →]   [See how it works] (optional secondary link)
```

**Illustration:** Lottie animation — phone → push notification → food item glows → checkmark. 3-second loop.

**No:** No signup form here. No email. No password. None of that.

---

## Step 2: Location Permission

**Why shown:** Location is needed for weather signal (OpenWeatherMap requires lat/lon) and nearest-restaurant lookup.

**Copy:**
```
[Location pin icon, animated drop]

"Rainy evenings call for comfort food."

"We use your location for weather — it's one of our
 strongest predictors. We never store your location history."

[Allow Location]

[Skip for now] → (shows reduced-accuracy warning, then continues)
```

**On allow:** System location dialog fires. If granted → continue to step 3.
**On skip:** `latitude/longitude` stays null → weather fallback to city-level from Swiggy profile. Note shown: "Weather predictions will be less accurate without location."

---

## Step 3: Swiggy Connect (Required)

**Why shown:** Order history is the core input. Without it, there is no product.

**Copy:**
```
[Swiggy logo + CravingsAPI logo with connecting lines]

"Connect your Swiggy account to unlock predictions."

"We read your past orders to learn your patterns.
 We never store your passwords or payment info."

[Connect Swiggy →]
```

**On tap:** Open in-app browser (WebView) pointing to Swiggy OAuth2 URL. On OAuth success → deep link back → close WebView → proceed to step 4. On OAuth cancel/failure → stay on step 3, show retry.

**This step cannot be skipped.** Copy makes this clear without being aggressive: "This is how CravingsAPI learns what you love."

---

## Step 4: Health Signals (Optional)

**Why shown:** Sleep and steps meaningfully improve prediction accuracy. But this is sensitive data. Opt-in only.

**Copy:**
```
[Health app icon (platform-appropriate)]

"Smarter predictions with your health data."

Sleep quality and daily activity change what we crave.
With your permission, we use:
• Last night's sleep duration
• Today's step count

That's it. We never see workout details, weight, or medical data.

[Connect Apple Health]   [Connect Google Fit]   [Skip →]
```

**"Skip →" is equal weight to connect buttons.** Not hidden. The app works fully without this.

**On connect:** System HealthKit/Fit permission sheet fires. Request only: `sleepAnalysis`, `stepCount`.
**On skip:** Continue to home. `health_signals_enabled = false`.

---

## Notification Permission

**Not asked during onboarding.** Notification permission is requested when the first prediction is ready, in-context:

```
[Prediction card loads]
  → Banner at top: "Allow notifications to receive predictions at the right time"
  → [Allow] button → system notification permission dialog
  → On grant: FCM token registered
  → On deny: banner dismissed, shown again after 48 hours (max 2 times)
```

**Why delayed:** Users grant notification permission more readily when they've already seen value (the first prediction card).

---

## Returning User (Re-install)

If user has existing account (matching Swiggy user ID from OAuth):
- Skip all onboarding steps
- Land on home screen with existing predictions
- Show toast: "Welcome back! Your predictions are ready."
- Re-request FCM token registration silently

---

## Drop-off Recovery

If user abandons mid-onboarding and re-opens:
- Resume from the last incomplete step
- Don't restart from step 1
- Location: if already granted, skip to step 3
- Swiggy OAuth: if token already exists, skip to step 4

---

## Analytics Events

| Event | When Fired |
|---|---|
| `onboarding_started` | Step 1 viewed |
| `onboarding_location_granted` | iOS/Android location permission granted |
| `onboarding_location_skipped` | User taps skip on step 2 |
| `onboarding_swiggy_connected` | OAuth callback success |
| `onboarding_swiggy_failed` | OAuth error |
| `onboarding_health_connected` | HealthKit/Fit granted |
| `onboarding_health_skipped` | User taps skip on step 4 |
| `onboarding_completed` | Home screen first load |
| `onboarding_abandoned` | App background/killed during onboarding |

Funnel target: ≥ 75% of users who start onboarding complete it (reach home screen).

Swiggy connect completion rate: ≥ 85% of users who reach step 3. If this drops below 80%, revisit step 3 copy.

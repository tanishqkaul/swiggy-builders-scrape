# UI Audit — CravingsAPI

> Screen-by-screen review of every state, edge case, and accessibility concern.

---

## Screen 1: Onboarding — Step 1 (Location)

### States
| State | What's Shown |
|---|---|
| Default | Permission explanation card + "Allow Location" CTA |
| Granted | Auto-advance to step 2 with success animation |
| Denied | "Location helps us predict better" + "Open Settings" button |
| Permanently denied (iOS) | Same as Denied — "Open Settings" deep links to iOS settings |

### Edge Cases
- User skips: Not possible — location is required (prediction quality drops to ~60% without it). CTA text makes this clear: "Needed for weather-based predictions."
- User goes back from step 2: Should NOT re-request permission. Detect `PermissionsAndroid.RESULTS.GRANTED` and skip ahead.

### Accessibility
- `accessibilityRole="button"` on "Allow Location" + "Open Settings"
- Location icon has `accessibilityLabel="Location pin icon"`
- Step indicator reads: "Step 1 of 3, Location permission"

---

## Screen 2: Onboarding — Step 2 (Health — Optional)

### States
| State | What's Shown |
|---|---|
| Default | Health benefit explanation + "Connect" + "Skip" (clearly equal weight) |
| HealthKit available (iOS) | "Connect Apple Health" button |
| Google Fit available (Android) | "Connect Google Fit" button |
| Neither available | Skip this step automatically |
| Connected | Show which permissions granted (sleep, steps) + "Continue" |
| Partially granted | Show what was granted, offer to "Update permissions" |
| Skipped | `health_signals_enabled = false` in DB. Step treated as complete. |

### Edge Cases
- User connects then revokes in Settings later: `useHealthSignals.ts` catches error on next read → silently disables in prefs, shows in-app nudge (not push) on next app open.
- Health data empty (new iPhone): Feature vector uses 0 values. Not an error.

### Accessibility
- "Skip" button must be same visual size as "Connect" — don't hide it.
- HealthKit auth dialog is system-provided, no control needed.

---

## Screen 3: Onboarding — Step 3 (Swiggy Connect)

### States
| State | What's Shown |
|---|---|
| Default | "Connect Swiggy" explanation + CTA |
| WebView auth loading | In-app browser opens Swiggy OAuth URL |
| Auth success | Redirect to callback → app dismisses WebView → proceeds to home |
| Auth failed | Error toast "Couldn't connect Swiggy. Try again." + retry button |
| Network offline | "No internet connection. Check your connection and retry." |

### Edge Cases
- User closes WebView mid-auth: WebView dismiss detected → stay on step 3 screen, not crash.
- Swiggy returns error in OAuth callback: Parse `error` param from redirect URL → show specific error (e.g., "You denied access. Open Swiggy and try again.").
- User already connected Swiggy in a previous session: Skip step 3, go to home. Detect via existing `swiggy_tokens` row.

---

## Screen 4: Home

### States
| State | What's Shown |
|---|---|
| Prediction ready | `PredictionCard` with item, confidence, context strip |
| No prediction yet | "CravingsAPI is learning your patterns. Check back in a few hours." + skeleton |
| Low confidence (all < threshold) | "Nothing certain today — here's your most-ordered item" + fallback card |
| Loading | Shimmer skeleton matching PredictionCard dimensions |
| Notification permission not granted | Banner: "Allow notifications to get predictions at the right time" + CTA |
| No order history | "Connect your Swiggy account to see predictions" |
| Error state | "Couldn't load your prediction. Pull to refresh." |

### Layout
```
StatusBar (transparent)
─────────────────────────────
Avatar + "Good [morning/afternoon/evening], [name]"   ← time-aware greeting
[StreakBadge] "7-day streak"

[PredictionCard — 80% of screen width, centered]

[View history →]                                       ← link to history screen

[Signal context pill row]                              ← scrollable horizontal
  [🌧️ Rainy] [🌙 Evening] [📅 Thursday]
─────────────────────────────
TabBar: Home | History | Settings
```

### Edge Cases
- Long restaurant name: Truncate at 1 line, `numberOfLines={1}` with ellipsis.
- Long item name: Max 2 lines. Never overflows card.
- Item image 404: Show cuisine-category placeholder illustration.
- Prediction from 6 hours ago: Show "From earlier today" label, muted styling.

---

## Screen 5: Confirm Order (Bottom Sheet)

### States
| State | What's Shown |
|---|---|
| Cart ready (from Redis) | Item details + animated 5-second countdown ring |
| Cart building (on-demand) | "Preparing your order…" spinner + item details |
| Cart unavailable | "Item might not be available. Check Swiggy directly." + deep link |
| Countdown at 0 | Auto-confirm triggers. Show "Order placed!" |
| User taps Confirm before countdown | Instant confirm |
| User taps Cancel | Bottom sheet dismisses. Prediction outcome = 'dismissed'. |
| Order in progress | "Placing order…" loading state on button |
| Order success | Success animation (lottie confetti) + order details |
| Order failure | Error state: "Couldn't place order. Try in Swiggy directly." + deep link |

### Critical UX Notes
- The 5-second auto-confirm is **opt-in** — toggled in Settings. Default: requires explicit tap.
- Cancel must always be reachable — don't obscure it during countdown.
- Haptic: `.impactOccurred(.heavy)` on successful order placement.
- Accessibility: announce "Order confirmed" to VoiceOver/TalkBack on success.

### Edge Cases
- User taps notification after cart expired (> 90 min): Cart built on-demand. Max wait: 5s. If Swiggy MCP slow: show skeleton + "almost ready".
- Item sold out after cart built: Swiggy MCP returns error on order placement → show "This item is sold out. Here's another option:" + fallback suggestion.
- Price changed between cart-build and order: Swiggy MCP handles this — show updated price before confirm.

---

## Screen 6: History

### States
| State | What's Shown |
|---|---|
| Has history | Timeline list: prediction vs actual order, accuracy indicators |
| No history (new user) | "Your prediction history will appear here." |
| Loading | Skeleton list |
| Prediction hit | Green check + "Predicted: Biryani · Ordered: Biryani" |
| Prediction miss | Amber X + "Predicted: Biryani · Ordered: Pasta" |
| No order that day | Gray dash + "Predicted: Maggi · You didn't order" |

### Edge Cases
- Partial match (predicted category correct, wrong item): Show partial match indicator (amber check, not full green).
- User ordered multiple times in one day: Match to prediction if any order matches. If multiple match, count as hit.

---

## Screen 7: Settings

### Sections
1. **Predictions** — confidence threshold slider (0.4–0.9), quiet hours picker
2. **Notifications** — toggle on/off, max per day (1 or 2)
3. **Connected Services** — Swiggy (always connected), Health (connect/disconnect)
4. **Privacy** — view what data we store, download my data, delete account
5. **Debug** (dev builds only) — force prediction, view raw signals, clear cache

### Edge Cases
- Disconnecting HealthKit: Confirm dialog "This will lower prediction accuracy." → on confirm, mark `is_active = false` in `health_connections`.
- Delete account: 2-step confirm → "Type DELETE to confirm" → soft delete + 30-day purge schedule.
- Confidence threshold at minimum (0.4): Show warning "You'll get more notifications but lower accuracy."

---

## Global Edge Cases

| Case | Handling |
|---|---|
| No internet (offline) | Show last cached prediction. Toast: "You're offline — showing last known prediction." |
| App backgrounded during order | Order continues. On foreground: show current order status. |
| Deep link from expired notification | Notif > 4h old → open history screen instead of confirm. |
| Two devices, same account | Latest `fcm_token` wins. Both devices may receive notif briefly during transition. |
| User uninstalls + reinstalls | FCM token changes. Old token becomes invalid, cleared on next send attempt. |
| Swiggy order history < 7 days | Rule-based fallback only. Show onboarding nudge: "Use Swiggy for a week to unlock AI predictions." |

---

## Accessibility Checklist

- [ ] All buttons ≥ 44×44pt touch target
- [ ] Color is never the sole differentiator (confidence bar also has % text)
- [ ] VoiceOver focus order matches visual order on all screens
- [ ] Pull-to-refresh announced: "Refreshing predictions"
- [ ] Loading states have `accessibilityLiveRegion="polite"`
- [ ] Error states have `accessibilityLiveRegion="assertive"`
- [ ] Bottom sheet traps focus when open (no background tab stop)
- [ ] Countdown timer announced: "Order confirms in X seconds" (every 2s update)
- [ ] Dynamic type supported up to Accessibility XXL (layout tested)
- [ ] All images have `accessibilityLabel` or `accessibilityIgnoresInvertColors` where appropriate

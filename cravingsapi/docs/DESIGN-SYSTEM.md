# Design System — CravingsAPI

## Brand Identity

**Tagline:** *Eat before you're hungry.*
**Personality:** Playfully confident, a little eerie, trustworthy. Never clinical.
**Tone:** The app speaks like a friend who knows you too well. "We knew you'd want this."

---

## Color Tokens

```
// Primary — Deep Indigo (intelligence, calm)
--color-primary-50:   #eef2ff
--color-primary-100:  #e0e7ff
--color-primary-400:  #818cf8
--color-primary-500:  #6366f1   ← main brand
--color-primary-600:  #4f46e5
--color-primary-900:  #1e1b4b

// Accent — Warm Amber (food, warmth, appetite)
--color-accent-300:   #fcd34d
--color-accent-400:   #fbbf24   ← notification glow
--color-accent-500:   #f59e0b

// Success — Jade Green
--color-success-400:  #34d399
--color-success-500:  #10b981

// Danger — Coral
--color-danger-400:   #f87171
--color-danger-500:   #ef4444

// Neutrals — Warm Gray (not cold gray)
--color-neutral-50:   #fafaf9
--color-neutral-100:  #f5f5f4
--color-neutral-200:  #e7e5e4
--color-neutral-400:  #a8a29e
--color-neutral-600:  #57534e
--color-neutral-800:  #292524
--color-neutral-900:  #1c1917

// Background
--color-bg-primary:   #0f0e17   ← dark base
--color-bg-card:      #1a1825
--color-bg-elevated:  #221f2e
```

---

## Typography

**Font:** `Plus Jakarta Sans` (headings) + `Inter` (body) — both system-available via Expo Google Fonts.

```
// Type Scale
--text-xs:    11px / 16px  letter-spacing: 0.4px
--text-sm:    13px / 20px
--text-base:  15px / 24px
--text-md:    17px / 26px
--text-lg:    20px / 28px  font: Plus Jakarta Sans SemiBold
--text-xl:    24px / 32px  font: Plus Jakarta Sans Bold
--text-2xl:   30px / 38px  font: Plus Jakarta Sans ExtraBold
--text-3xl:   38px / 46px  font: Plus Jakarta Sans ExtraBold

// Weight
--font-regular:    400
--font-medium:     500
--font-semibold:   600
--font-bold:       700
--font-extrabold:  800
```

---

## Spacing & Layout

```
// 4px base grid
--space-1:   4px
--space-2:   8px
--space-3:   12px
--space-4:   16px
--space-5:   20px
--space-6:   24px
--space-8:   32px
--space-10:  40px
--space-12:  48px
--space-16:  64px

// Border radius
--radius-sm:   6px
--radius-md:   12px
--radius-lg:   20px
--radius-xl:   28px
--radius-full: 9999px

// Shadows (dark theme — glow-based)
--shadow-card: 0 4px 24px rgba(99, 102, 241, 0.12)
--shadow-glow: 0 0 32px rgba(251, 191, 36, 0.25)   ← notification pulse
--shadow-modal: 0 -8px 48px rgba(0,0,0,0.5)
```

---

## Component Specifications

### PredictionCard
The hero component. Shown on home screen.

```
┌──────────────────────────────────────┐
│  🌧️  Rainy evening · Thu · 7:30 PM  │  ← context strip (text-xs, neutral-400)
│                                        │
│  [Item image — 80x80 rounded-xl]      │
│                                        │
│  Chicken Biryani                       │  text-2xl ExtraBold, white
│  Behrouz Biryani · 2.1 km             │  text-sm, neutral-400
│                                        │
│  ━━━━━━━━━━━━━━━━━━━━  87%            │  confidence bar (primary-500 fill)
│  "We're 87% sure about this one."     │  text-sm, neutral-400, italic
│                                        │
│  [  Pre-order now  ]   [  Not now  ]   │  buttons
└──────────────────────────────────────┘

Background: gradient bg-card → bg-elevated
Border: 1px solid rgba(255,255,255,0.06)
Shadow: shadow-card
Animation: entry → slide-up + fade (300ms, ease-out)
```

**Confidence bar color:**
- ≥ 0.80 → `success-400` (jade)
- 0.60–0.79 → `primary-500` (indigo)
- 0.40–0.59 → `accent-400` (amber)
- < 0.40 → `danger-400` (coral) — never shown (below threshold)

### OrderConfirmSheet (Bottom Sheet)
```
Height: 60% of screen
Backdrop: blur(20px) + rgba(0,0,0,0.7)
Handle: 4x40px, neutral-600, radius-full, centered

[Item image — 120x120 rounded-xl, centered]
[Item name — text-xl Bold, centered]
[Restaurant · Price — text-md, neutral-400, centered]

──────────────────────────────────
[  Confirm order  ]                     ← primary-500 bg, full width, radius-full
Countdown ring: 5-second animated ring around button
After 5s: auto-trigger if user doesn't cancel

[  Cancel  ]                            ← text-sm, neutral-400, ghost
```

### StreakBadge
```
28x28px circle, primary-500 border 2px
Interior: streak count (text-sm Bold, white)
Tooltip on long-press: "X correct predictions this week"
```

### Notification Copy Templates
```
High confidence (≥ 0.80):
  Title: "We know what you want 👀"
  Body:  "Chicken Biryani from Behrouz Biryani — tap to pre-order"

Medium confidence (0.60–0.79):
  Title: "Feeling like [item]?"
  Body:  "You usually order this on rainy Thursdays. One tap away."

Weather-driven:
  Title: "Cold + hungry = [item]"
  Body:  "It's 16°C outside. Your Maggi is one tap away."

Weekend vibes:
  Title: "Friday night, you know what to do 🎉"
  Body:  "[Item] from [Restaurant] — let's go."
```

---

## Motion System

| Interaction | Animation | Duration | Easing |
|---|---|---|---|
| Screen enter | slide-up + fade-in | 300ms | ease-out-cubic |
| Card appear | slide-up + fade | 250ms | spring (stiffness: 200, damping: 20) |
| Bottom sheet open | slide-up | 350ms | ease-out-expo |
| Bottom sheet close | slide-down | 280ms | ease-in-cubic |
| Confidence bar fill | width 0→final | 800ms | ease-out-elastic |
| Countdown ring | stroke-dashoffset | 5000ms | linear |
| Success haptic | heavy impact | — | — |
| Prediction tap | scale 0.97 | 120ms | ease-in-out |
| Notification pulse | glow expand-contract | 2000ms loop | ease-in-out |

---

## Dark Mode Only

CravingsAPI ships dark-mode-only (v1). Food photography is dramatically better on dark backgrounds. "Midnight craving" aesthetic is intentional brand positioning.

---

## Accessibility

- **Minimum contrast ratio:** 4.5:1 for body text (WCAG AA). Headers: 3:1.
- All interactive elements: minimum 44×44pt touch target.
- `accessibilityLabel` on all icon-only buttons.
- `accessibilityRole="button"` on PredictionCard tap area.
- Reduced motion: if `AccessibilityInfo.isReduceMotionEnabled` → disable confidence bar animation, replace spring with instant state.
- Screen reader: VoiceOver/TalkBack compatible for all core flows.
- Font scaling: `allowFontScaling={true}` globally, max scale factor 1.3 for card layouts.

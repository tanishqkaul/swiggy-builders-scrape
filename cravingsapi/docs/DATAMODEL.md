# Data Model — CravingsAPI

## Entity Relationship Overview

```
users ─────────────────────────────────────┐
  │                                         │
  ├── user_preferences (1:1)                │
  ├── swiggy_tokens (1:1, encrypted)        │
  ├── health_connections (1:N)              │
  ├── signal_snapshots (1:N)                │
  ├── predictions (1:N)  ─── notification_events (1:N)
  └── orders (1:N)
```

---

## Tables

### `users`
```sql
CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  swiggy_user_id  TEXT UNIQUE NOT NULL,          -- Swiggy's user identifier
  email           TEXT UNIQUE,                   -- from Swiggy profile
  display_name    TEXT,
  phone_hash      TEXT,                          -- SHA-256 of phone, for dedup
  timezone        TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  latitude        DECIMAL(9,6),                  -- last known location
  longitude       DECIMAL(9,6),
  fcm_token       TEXT,                          -- Firebase device token
  app_version     TEXT,
  platform        TEXT CHECK (platform IN ('ios', 'android')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at  TIMESTAMPTZ,
  deleted_at      TIMESTAMPTZ                    -- soft delete
);
```

### `user_preferences`
```sql
CREATE TABLE user_preferences (
  user_id                UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  notifications_enabled  BOOLEAN NOT NULL DEFAULT true,
  quiet_hours_start      TIME NOT NULL DEFAULT '22:00',
  quiet_hours_end        TIME NOT NULL DEFAULT '07:00',
  max_notifs_per_day     SMALLINT NOT NULL DEFAULT 2,
  confidence_threshold   DECIMAL(3,2) NOT NULL DEFAULT 0.55,
  dietary_flags          TEXT[] DEFAULT '{}',    -- ['vegetarian', 'jain', 'vegan']
  max_order_value        INTEGER,                -- INR, null = no limit
  health_signals_enabled BOOLEAN NOT NULL DEFAULT false,
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `swiggy_tokens`
```sql
CREATE TABLE swiggy_tokens (
  user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  access_token   TEXT NOT NULL,                  -- AES-256-GCM encrypted at rest
  refresh_token  TEXT NOT NULL,                  -- AES-256-GCM encrypted at rest
  expires_at     TIMESTAMPTZ NOT NULL,
  scope          TEXT NOT NULL,                  -- space-separated OAuth scopes
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `sahha_connections`
```sql
-- Replaces health_connections. Sahha handles cross-platform HealthKit/Health Connect.
CREATE TABLE sahha_connections (
  user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  external_id        TEXT NOT NULL UNIQUE,           -- 'cravingsapi_user_{user_id}'
  profile_token      TEXT NOT NULL,                  -- AES-256-GCM encrypted; used by mobile SDK
  sensors_granted    TEXT[] DEFAULT '{}',            -- ['sleep', 'heart', 'activity']
  has_wearable       BOOLEAN NOT NULL DEFAULT false, -- updated when wearable biomarkers return non-null
  connected_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_biomarker_at  TIMESTAMPTZ,                    -- last successful Sahha biomarker received
  last_score_at      TIMESTAMPTZ,                    -- last successful Sahha score received
  -- Set to true when Sahha launches reproductive biomarkers in 2026
  reproductive_enabled BOOLEAN NOT NULL DEFAULT false,
  is_active          BOOLEAN NOT NULL DEFAULT true
);
```

### `cycle_profiles`
```sql
-- Ultra-sensitive. Column-level encryption on all date fields.
-- Separate RLS policy: only the owning user can read, no admin read without explicit audit log.
CREATE TABLE cycle_profiles (
  user_id               UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_period_start     DATE NOT NULL,               -- AES-256-GCM encrypted at column level
  avg_cycle_length      SMALLINT NOT NULL DEFAULT 28, -- 21–45 day range enforced
  cycle_length_std      DECIMAL(4,2),                -- standard deviation of past cycle lengths
  tracking_started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_logged_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  period_entries        INTEGER NOT NULL DEFAULT 1,  -- number of logged periods (accuracy proxy)
  reminder_enabled      BOOLEAN NOT NULL DEFAULT true,
  reminder_days_before  SMALLINT NOT NULL DEFAULT 3,  -- remind N days before predicted period
  -- Sahha confirmation tracking
  sahha_phase_mismatch_count  SMALLINT DEFAULT 0,    -- consecutive cycles where Sahha contradicted logged phase
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Separate audit log for any admin access to cycle_profiles (legal requirement)
CREATE TABLE cycle_data_access_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL,
  accessed_by TEXT NOT NULL,     -- 'user_self' | 'system_prediction' | 'admin_{id}'
  reason      TEXT,
  accessed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `cycle_period_log`
```sql
-- Full history of logged period start dates (enables cycle length calculation)
CREATE TABLE cycle_period_log (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,      -- AES-256-GCM encrypted
  logged_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  source     TEXT NOT NULL CHECK (source IN ('user_manual', 'system_suggested', 'imported'))
);

CREATE INDEX idx_period_log_user ON cycle_period_log (user_id, start_date DESC);
```

### `signal_snapshots`
```sql
CREATE TABLE signal_snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  captured_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Weather signals
  temp_celsius    DECIMAL(5,2),
  feels_like      DECIMAL(5,2),
  humidity        SMALLINT,
  weather_code    SMALLINT,                      -- OWM weather condition code
  is_raining      BOOLEAN,
  -- Time signals
  hour_of_day     SMALLINT,
  day_of_week     SMALLINT,
  is_weekend      BOOLEAN,
  -- Order history signals
  orders_last_7d  SMALLINT,
  orders_last_30d SMALLINT,
  avg_order_value INTEGER,                       -- INR paisa
  last_order_hrs  DECIMAL(6,2),
  -- Sahha scores (no wearable needed — null if Sahha not connected)
  sahha_sleep_score        DECIMAL(4,3),
  sahha_readiness_score    DECIMAL(4,3),
  sahha_mental_wellbeing   DECIMAL(4,3),
  sahha_activity_score     DECIMAL(4,3),
  -- Sahha biomarkers — no wearable (null if Sahha not connected)
  sahha_sleep_duration_min INTEGER,                 -- minutes, from biomarker.sleep_duration
  sahha_sleep_regularity   DECIMAL(4,3),            -- index 0–1, biomarker.sleep_regularity (weekly)
  sahha_sleep_debt_hours   DECIMAL(5,2),            -- biomarker.sleep_debt
  sahha_steps              INTEGER,                 -- biomarker.steps
  sahha_sedentary_min      INTEGER,                 -- biomarker.activity_sedentary_duration
  -- Sahha biomarkers — wearable required (null if no wearable detected)
  sahha_has_wearable       BOOLEAN NOT NULL DEFAULT false,
  sahha_hrv_sdnn_ms        DECIMAL(6,2),            -- biomarker.heart_rate_variability_sdnn
  sahha_hrv_rmssd_ms       DECIMAL(6,2),            -- biomarker.heart_rate_variability_rmssd
  sahha_resting_hr_bpm     DECIMAL(5,2),            -- biomarker.heart_rate_resting
  sahha_sleep_efficiency   DECIMAL(4,3),            -- biomarker.sleep_efficiency (ratio 0–1)
  sahha_bbt_celsius        DECIMAL(5,3),            -- biomarker.body_temperature_basal (BBT — gold standard)
  sahha_bbt_delta          DECIMAL(5,3),            -- delta from user's 14-day BBT baseline
  sahha_skin_temp_sleep    DECIMAL(5,3),            -- biomarker.skin_temperature_sleep
  -- Sahha archetypes
  sahha_sleep_pattern      TEXT,                    -- archetype.sleep_pattern label
  sahha_activity_level     TEXT,                    -- archetype.activity_level label
  -- Menstrual cycle signals (null if not tracking)
  cycle_phase              TEXT CHECK (cycle_phase IN ('menstrual','follicular','ovulatory','luteal')),
  cycle_day                SMALLINT,
  days_until_period        SMALLINT,
  phase_sahha_confirmed    BOOLEAN,
  phase_confidence_mult    DECIMAL(4,3),
  -- Raw feature vector stored as jsonb for model retraining
  feature_vector  JSONB NOT NULL
);

CREATE INDEX idx_signal_snapshots_user_time ON signal_snapshots (user_id, captured_at DESC);
```

### `predictions`
```sql
CREATE TABLE predictions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signal_id       UUID REFERENCES signal_snapshots(id),
  predicted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  item_id         TEXT NOT NULL,                 -- Swiggy item ID
  item_name       TEXT NOT NULL,
  item_image_url  TEXT,
  restaurant_id   TEXT,
  restaurant_name TEXT,
  confidence      DECIMAL(4,3) NOT NULL,         -- 0.000–1.000
  window_start    TIME,                          -- predicted craving window
  window_end      TIME,
  model_version         TEXT NOT NULL,            -- e.g. 'v1.2.0'
  fallback_used         BOOLEAN NOT NULL DEFAULT false,
  cycle_phase           TEXT,                     -- phase at prediction time (denormalized for analytics)
  cycle_day             SMALLINT,
  phase_override_applied BOOLEAN NOT NULL DEFAULT false,
  -- Outcome tracking
  notif_fired_at  TIMESTAMPTZ,
  cart_id         TEXT,                          -- Redis cart key
  cart_built_at   TIMESTAMPTZ,
  cart_expires_at TIMESTAMPTZ,
  order_id        UUID REFERENCES orders(id),    -- null until ordered
  outcome         TEXT CHECK (outcome IN ('ordered', 'dismissed', 'expired', 'pending'))
                  DEFAULT 'pending'
);

CREATE INDEX idx_predictions_user_outcome ON predictions (user_id, predicted_at DESC);
CREATE INDEX idx_predictions_pending ON predictions (outcome) WHERE outcome = 'pending';
```

### `orders`
```sql
CREATE TABLE orders (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id),
  swiggy_order_id   TEXT UNIQUE,                 -- Swiggy's order reference
  prediction_id     UUID REFERENCES predictions(id),
  placed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  item_name         TEXT NOT NULL,
  restaurant_name   TEXT NOT NULL,
  total_amount      INTEGER NOT NULL,            -- INR paisa
  status            TEXT NOT NULL DEFAULT 'placed',
  -- 'placed' | 'confirmed' | 'preparing' | 'out_for_delivery' | 'delivered' | 'cancelled'
  delivered_at      TIMESTAMPTZ,
  cancelled_at      TIMESTAMPTZ,
  cancel_reason     TEXT
);
```

### `notification_events`
```sql
CREATE TABLE notification_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prediction_id   UUID NOT NULL REFERENCES predictions(id),
  user_id         UUID NOT NULL REFERENCES users(id),
  event_type      TEXT NOT NULL CHECK (event_type IN ('sent', 'opened', 'dismissed', 'ordered', 'cart_expired')),
  occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  fcm_message_id  TEXT,
  metadata        JSONB DEFAULT '{}'
);

CREATE INDEX idx_notif_events_user ON notification_events (user_id, occurred_at DESC);
```

---

## Redis Keys

| Key Pattern | TTL | Value | Purpose |
|---|---|---|---|
| `cart:{prediction_id}` | 90 min | JSON SwiggyCart | Pre-built cart for one-tap order |
| `pred_lock:{user_id}` | 15 min | "1" | Prevents duplicate prediction runs |
| `notif_count:{user_id}:{date}` | 24 hr | integer | Daily notification counter |
| `quiet:{user_id}` | computed | "1" | Set during user quiet hours |
| `fcm_job:{prediction_id}` | 2 hr | JSON FCM payload | Scheduled notification job |
| `sahha:{user_id}:signals` | 30 min | JSON SahhaSignals | Cached Sahha biomarker/score fetch |
| `bbt:{user_id}:series` | 15 days | JSON float[] | Last 14 days of BBT readings for delta computation |
| `cycle:{user_id}:phase` | 6 hr | JSON CyclePhase | Current computed phase (avoids DB read per signal cycle) |

---

## Data Lifecycle & Retention

| Data | Retention | Reason |
|---|---|---|
| `signal_snapshots` | 180 days | Training data window |
| `predictions` | 1 year | User history + model evaluation |
| `orders` | Indefinite | Legal + accounting |
| `notification_events` | 90 days | CTR/conversion analytics |
| `swiggy_tokens` | Until revoked | Required for API calls |
| `sahha_connections` | Until user disconnects | Opt-in |
| **`cycle_profiles`** | **Until user explicitly deletes** | **Sensitive — never auto-purged** |
| **`cycle_period_log`** | **Until user explicitly deletes** | **Same — user owns this data** |
| **`cycle_data_access_log`** | **3 years** | **Legal/compliance audit trail** |
| Redis carts | 90 min TTL | Auto-expires |

---

## Anonymization Rules

- `phone_hash` stored instead of raw phone — one-way SHA-256
- `swiggy_tokens.access_token` and `refresh_token` — AES-256-GCM encrypted with per-row IV, key stored in Railway secret (not in DB)
- `sahha_connections.profile_token` — same encryption as swiggy tokens
- **`cycle_profiles.last_period_start`** — **column-level AES-256-GCM encryption, separate encryption key (`CYCLE_DATA_KEY`) from the main token key**
- **`cycle_period_log.start_date`** — same column-level encryption
- `feature_vector` JSONB contains no PII — only aggregated behavioral metrics. The `cycle_phase` field in signal_snapshots is a category label (not a date) and is not considered PII.
- On account deletion (`deleted_at` set): `swiggy_tokens` deleted immediately, `sahha_connections` deleted (triggers Sahha profile deletion via API), `signal_snapshots.feature_vector` zeroed — other records retained for 30 days then purged by cron
- **On cycle data deletion (independent of account deletion):** `cycle_profiles` hard-deleted within 24 hours, `cycle_period_log` hard-deleted within 24 hours, `signal_snapshots.cycle_phase` and related columns set to NULL, `cycle_data_access_log` retained 3 years per compliance requirement

---

## Database Indexes (Full List)

```sql
-- Prediction lookup (hot path)
CREATE INDEX idx_predictions_user_pending ON predictions (user_id, predicted_at DESC)
  WHERE outcome = 'pending';

-- Signal aggregation
CREATE INDEX idx_signal_user_recent ON signal_snapshots (user_id, captured_at DESC);

-- Notification analytics
CREATE INDEX idx_notif_events_pred ON notification_events (prediction_id, event_type);

-- Order lookup
CREATE INDEX idx_orders_user ON orders (user_id, placed_at DESC);
CREATE INDEX idx_orders_swiggy_id ON orders (swiggy_order_id);
```

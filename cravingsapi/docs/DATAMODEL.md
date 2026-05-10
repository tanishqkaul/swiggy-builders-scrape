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

### `health_connections`
```sql
CREATE TABLE health_connections (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider     TEXT NOT NULL CHECK (provider IN ('apple_health', 'google_fit')),
  access_token TEXT NOT NULL,                    -- encrypted
  scopes       TEXT[],                           -- e.g. ['sleep', 'steps']
  connected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_sync_at TIMESTAMPTZ,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (user_id, provider)
);
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
  -- Health signals (null if not connected)
  sleep_hours     DECIMAL(4,2),
  steps_today     INTEGER,
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
  model_version   TEXT NOT NULL,                 -- e.g. 'v1.2.0'
  fallback_used   BOOLEAN NOT NULL DEFAULT false,
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

---

## Data Lifecycle & Retention

| Data | Retention | Reason |
|---|---|---|
| `signal_snapshots` | 180 days | Training data window |
| `predictions` | 1 year | User history + model evaluation |
| `orders` | Indefinite | Legal + accounting |
| `notification_events` | 90 days | CTR/conversion analytics |
| `swiggy_tokens` | Until revoked | Required for API calls |
| `health_connections` | Until user disconnects | Opt-in |
| Redis carts | 90 min TTL | Auto-expires |

---

## Anonymization Rules

- `phone_hash` stored instead of raw phone — one-way SHA-256
- `swiggy_tokens.access_token` and `refresh_token` — AES-256-GCM encrypted with per-row IV, key stored in Railway secret (not in DB)
- `health_connections.access_token` — same encryption
- `feature_vector` JSONB contains no PII — only aggregated behavioral metrics
- On account deletion (`deleted_at` set): `swiggy_tokens` row deleted immediately, `health_connections` rows deleted, `signal_snapshots.feature_vector` zeroed out, other records retained for 30 days then purged by cron

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

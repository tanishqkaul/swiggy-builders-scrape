# Security — CravingsAPI

## Threat Model

| Asset | Threat | Likelihood | Impact |
|---|---|---|---|
| Swiggy access tokens | Exfiltration from DB breach | Low (encrypted) | Critical |
| User order history | Unauthorized read | Low (RLS enforced) | High |
| **Menstrual cycle dates** | **Exfiltration or unauthorized read** | **Low (column-encrypted + audit log)** | **CRITICAL — legal/personal safety risk** |
| Sahha biomarkers | Exfiltration | Low (never stored raw, processed only) | High |
| FCM tokens | Spoofed notifications | Low (JWT-gated API) | Medium |
| JWT tokens | Stolen from device | Low (SecureStore) | High |
| PII (name, phone) | Data breach | Low | High |

---

## Menstrual Data — Special Category

Menstrual cycle data is a **special category of personal data** under DPDP Act 2023 (India) and GDPR (Article 9). Treat it with the highest possible care.

### Separate Encryption Key
Cycle data uses its own encryption key (`CYCLE_DATA_KEY`) stored separately in Railway secrets from the main `TOKEN_ENCRYPTION_KEY`. A breach of one key does not expose the other. Key rotation is independent.

### Column-Level Encryption
`cycle_profiles.last_period_start` and `cycle_period_log.start_date` are encrypted **before writing to the database** at the application layer — not just at rest by the DB provider. Even a full DB dump reveals only ciphertext for these columns.

```python
# services/cycle/crypto.py
def encrypt_date(d: date) -> str:
    """AES-256-GCM encrypt a date. Returns base64-encoded ciphertext:nonce."""
    key = settings.CYCLE_DATA_KEY  # 32-byte key from Railway env
    nonce = os.urandom(12)
    aesgcm = AESGCM(key)
    ct = aesgcm.encrypt(nonce, d.isoformat().encode(), None)
    return base64.b64encode(nonce + ct).decode()

def decrypt_date(ciphertext: str) -> date:
    raw = base64.b64decode(ciphertext)
    nonce, ct = raw[:12], raw[12:]
    plaintext = AESGCM(settings.CYCLE_DATA_KEY).decrypt(nonce, ct, None)
    return date.fromisoformat(plaintext.decode())
```

### Access Audit Log
Every read of `cycle_profiles` or `cycle_period_log` by any service is recorded in `cycle_data_access_log`. This includes:
- The prediction engine reading cycle phase during signal collection (`system_prediction`)
- The user reading their own cycle history (`user_self`)
- Any future admin access requires a separate `CYCLE_ADMIN_KEY` and must log a reason

### No Third-Party Exposure
Cycle phase is **never** sent to Swiggy MCP, OpenWeatherMap, Firebase FCM, or any external service. The phase override is applied entirely server-side. FCM notification payload contains only: item name, restaurant name — no health or cycle references.

### Notification Privacy
Push notifications never reference the cycle directly. Copy uses food-centric language only ("Comfort food time 🍫") — not "It's your luteal phase" or any health reference. This protects users whose notifications may be seen by others.

---

## Authentication

### Mobile → Backend
- JWTs signed by Supabase (RS256, 1-hour expiry)
- Refresh tokens stored in `expo-secure-store` (iOS Keychain / Android Keystore)
- All API calls attach: `Authorization: Bearer {jwt}`
- Token validation in FastAPI via `dependencies.py → get_current_user()` on every protected route

### Backend → Swiggy MCP
- Swiggy access tokens stored in PostgreSQL `swiggy_tokens` table
- **Encrypted at rest:** AES-256-GCM, key stored in Railway environment secret (`SWIGGY_TOKEN_ENCRYPTION_KEY`), never in DB
- Decrypted in memory only when making MCP calls — not logged, not returned to client

### Backend → External APIs
- OpenWeatherMap: API key in Railway env vars, never exposed to client
- Firebase Admin: Service account JSON in Railway env vars
- Supabase: Service role key in Railway env vars (never the anon key on the backend)

---

## Authorization

- Row Level Security (RLS) enabled on **all** PostgreSQL tables
- Users can only read their own rows — enforced at DB level, not just API level
- Admin routes (`/admin/*`) require `role=admin` claim in JWT — set manually in Supabase
- Signal data, predictions, orders: all scoped to `auth.uid() = user_id`

---

## Data Privacy

### PII Minimization
| Data | What We Store | What We Don't |
|---|---|---|
| Phone | SHA-256 hash (dedup only) | Raw phone number |
| Health data | Aggregated (sleep_hours, steps_today) | Raw HealthKit records |
| Location | Lat/lon at city resolution | Precise GPS track |
| Order history | Feature-engineered aggregates | Raw order item list beyond history window |
| Swiggy tokens | Encrypted at rest | Plaintext anywhere |

### GDPR / Privacy Compliance
- "Download my data" endpoint: `GET /users/me/data-export` → returns JSON of all stored user data
- "Delete my account" endpoint: `DELETE /users/me` → immediate soft delete, 30-day hard purge
- Privacy policy link required on onboarding step 1
- Health data opt-in: explicit consent screen, re-confirmable in settings
- Users can disconnect any integration without deleting account

---

## Transport Security

- All traffic: HTTPS/TLS 1.3 minimum
- Railway enforces HTTPS — HTTP traffic rejected at load balancer
- HSTS header on all API responses: `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- Certificate: Railway-managed Let's Encrypt

---

## Input Validation

- All request bodies validated via Pydantic schemas before reaching service layer
- UUID format validated on all `user_id`, `prediction_id` params
- Enum fields (platform, dietary_flags, event_type) validated against allowlist
- No raw SQL queries — SQLAlchemy ORM only. No SQL injection surface.
- No `eval()`, no `exec()`, no dynamic imports based on user input

---

## Secrets Management

| Secret | Location | Rotation |
|---|---|---|
| `SWIGGY_TOKEN_ENCRYPTION_KEY` | Railway env var | Every 90 days |
| `SWIGGY_CLIENT_SECRET` | Railway env var | On compromise |
| `SUPABASE_SERVICE_ROLE_KEY` | Railway env var | Every 90 days |
| `OPENWEATHER_API_KEY` | Railway env var | On compromise |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Railway env var | Every 180 days |
| `JWT_SECRET` | Supabase-managed | Auto-rotated |

- Never committed to git (enforced via `.gitignore` + `gitleaks` pre-commit hook)
- Never logged — Sentry PII scrubbing configured to redact `authorization` headers and `token` fields

---

## Dependency Security

- `pip-audit` runs in CI on every PR — fails on known CVEs
- `npm audit` runs for mobile/web in CI
- Dependabot enabled for automatic patch PRs
- ONNX model file hash verified at load time (prevents model poisoning if artifact store is compromised)

---

## Rate Limiting

Applied at API Gateway level via Redis counters:

| Endpoint | Limit | Window |
|---|---|---|
| `POST /auth/*` | 10 req | per IP per minute |
| `GET /predictions/*` | 60 req | per user per minute |
| `POST /orders/confirm` | 5 req | per user per minute |
| All other endpoints | 120 req | per user per minute |
| Global per-IP | 300 req | per minute |

Returns `429` with `Retry-After` header and `RATE_LIMITED` error code.

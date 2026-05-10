# Security — CravingsAPI

## Threat Model

| Asset | Threat | Likelihood | Impact |
|---|---|---|---|
| Swiggy access tokens | Exfiltration from DB breach | Low (encrypted) | Critical |
| User order history | Unauthorized read | Low (RLS enforced) | High |
| Health signals | Exfiltration | Low (never stored raw) | High |
| FCM tokens | Spoofed notifications | Low (JWT-gated API) | Medium |
| JWT tokens | Stolen from device | Low (SecureStore) | High |
| PII (name, phone) | Data breach | Low | High |

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

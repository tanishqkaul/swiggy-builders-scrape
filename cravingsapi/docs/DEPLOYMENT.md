# Deployment — CravingsAPI

## Environments

| Environment | URL | Purpose | Deploy trigger |
|---|---|---|---|
| Local | localhost:8000 | Development | `uvicorn main:app --reload` |
| Preview | pr-{N}.cravingsapi.app | PR review | Automatic on PR open (Railway preview) |
| Staging | staging.cravingsapi.app | Pre-release testing | Manual push to `staging` branch |
| Production | api.cravingsapi.app | Live users | Merge to `main` + manual approval |

---

## Backend Deployment (Railway)

### `railway.toml`
```toml
[build]
builder = "DOCKERFILE"
dockerfilePath = "infra/docker/api.Dockerfile"

[deploy]
startCommand = "uvicorn main:app --host 0.0.0.0 --port $PORT --workers 2"
healthcheckPath = "/health"
healthcheckTimeout = 10
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

### `infra/docker/api.Dockerfile`
```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY services/api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/api/ .
COPY ml/models/ ./ml/models/
COPY ml/inference/ ./ml/inference/

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Environment Variables (Railway)
```
DATABASE_URL=postgresql+asyncpg://...
REDIS_URL=rediss://...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SWIGGY_CLIENT_ID=...
SWIGGY_CLIENT_SECRET=...
SWIGGY_TOKEN_ENCRYPTION_KEY=<32-byte hex>
OPENWEATHER_API_KEY=...
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
ENVIRONMENT=production
SENTRY_DSN=https://...
```

---

## Mobile Deployment (Expo EAS)

### Build Configuration (`eas.json`)
```json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal",
      "ios": { "simulator": false }
    },
    "production": {
      "autoIncrement": true
    }
  },
  "submit": {
    "production": {
      "ios": { "appleId": "...", "ascAppId": "..." },
      "android": { "serviceAccountKeyPath": "./google-service-account.json" }
    }
  }
}
```

### Build & Submit Commands
```bash
# Development build (internal testing)
eas build --profile development --platform all

# Production build + submit to stores
eas build --profile production --platform all
eas submit --platform all
```

---

## Web Dashboard Deployment (Vercel)

```json
// vercel.json
{
  "buildCommand": "cd apps/web && npm run build",
  "outputDirectory": "apps/web/.next",
  "framework": "nextjs",
  "env": {
    "NEXT_PUBLIC_API_URL": "https://api.cravingsapi.app",
    "NEXT_PUBLIC_SUPABASE_URL": "@supabase_url",
    "NEXT_PUBLIC_SUPABASE_ANON_KEY": "@supabase_anon_key"
  }
}
```

Deploy: automatic on `main` merge via Vercel GitHub integration.

---

## Database Migrations

```bash
# Generate migration
alembic revision --autogenerate -m "add health_connections table"

# Apply to environment
ENVIRONMENT=staging alembic upgrade head
ENVIRONMENT=production alembic upgrade head  # requires manual approval in CI
```

**Policy:** Migrations run before new code deploys. All migrations must be backwards-compatible (add columns with defaults, never drop without a two-phase approach).

---

## ML Model Deployment

1. Training completes on local/CI: `python ml/training/train.py`
2. Model exported to ONNX: `python ml/training/export.py --output ml/models/cravings_v{N}.onnx`
3. Model evaluated on holdout: `python ml/training/evaluate.py` — must pass AUC ≥ 0.78
4. Model artifact committed to `ml/models/` (tracked via Git LFS)
5. `ml/models/cravings_v1_meta.json` updated with version, date, AUC
6. Backend deployment picks up new model file from Docker image

**No live model reload.** Deployment required to update model. Downtime: 0 (Railway rolling deploy).

---

## Rollout Strategy

### Production Deploy Checklist
- [ ] All CI checks pass
- [ ] Staging tested with real Swiggy account
- [ ] DB migration dry-run (`alembic upgrade head --sql` reviewed)
- [ ] Sentry release created (`sentry-cli releases new v{version}`)
- [ ] At least 1 reviewer approved PR
- [ ] Railway deploy triggered
- [ ] Health check passing: `GET /health` returns `{"status":"ok"}`
- [ ] Smoke test: trigger prediction for test account, verify push received

### Rollback
- Railway: one-click rollback to previous deploy
- DB: `alembic downgrade -1` (only if migration is reversible)
- Mobile: previous binary stays on App Store, no forced update — users on old version unaffected until next open

---

## Monitoring

| Tool | Monitors | Alerts to |
|---|---|---|
| Sentry | Errors, performance, crashes | Slack `#alerts` |
| Railway Metrics | CPU, memory, request count | Railway dashboard |
| Upstash Console | Redis memory, commands/sec | Email |
| Firebase Console | FCM delivery rate, open rate | Email |
| Supabase Dashboard | DB connections, query perf | Dashboard only |
| Grafana Cloud | Custom metrics (prediction coverage, order rate) | PagerDuty (future) |

### Health Endpoint
```python
# GET /health
{
  "status": "ok",
  "version": "1.2.0",
  "db": "connected",
  "redis": "connected",
  "ml_model": "cravings_v1",
  "ml_model_auc": 0.81,
  "uptime_seconds": 3600
}
```

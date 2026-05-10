# SLA & Uptime | Swiggy Builders Club

**URL:** https://mcp.swiggy.com/builders/docs/operate/sla/

---

# SLA & uptime

Service-level objectives for Swiggy MCP endpoints.

Numbers below are **v1 targets**, not contractual commitments. Final SLA numbers are confirmed at contract sign with your partnership team; enterprise partners get bespoke remedies. Public SLO reporting infrastructure (status page, breach alerting) is on the v1.1 roadmap.

## Uptime targets

| Tier | Monthly uptime SLO | Monthly availability |
| --- | --- | --- |
| Production MCP endpoints (`/food`, `/im`, `/dineout`) | **99.9%** | ≤ 43 min downtime/month |
| OAuth endpoints (`/auth/*`) | 99.9% | ≤ 43 min downtime/month |
| Staging endpoints | Best-effort - no SLO in v1 | - |

## Latency targets

Measured at the MCP server edge, excluding client-side network and inference.

| Tool class | p50 | p95 | p99 |
| --- | --- | --- | --- |
| Read tools (e.g. `search_restaurants`) | `<200ms` | `<600ms` | `<1200ms` |
| Write tools (e.g. `update_food_cart`) | `<400ms` | `<1000ms` | `<2000ms` |
| Order placement (e.g. `place_food_order`) | `<800ms` | `<2000ms` | `<4000ms` |

Cold-path calls (first tool invocation of a session) may include session validation and can be slower than steady-state.

## Status page

A public status page at `status.swiggy.com/mcp` is shipping in **v1.1**. Until then, incident information flows via email to your designated engineering contact.

## Incident communication

For S0 / S1 incidents, we commit to:

1. **Acknowledgement** to your designated engineering contact during business hours (IST). Specific response-time targets are negotiated per partner contract.
2. **Regular written updates** until the incident is resolved.
3. **Root-cause analysis** shared after the incident is closed.

## Maintenance windows

Planned maintenance that may cause brief 5xx responses is announced **72 hours in advance** to your designated engineering contact. We avoid windows during Indian Standard Time peak meal hours (12:00-14:00 and 19:00-22:00 IST).

## Measurement

SLO is measured as successful request-response pairs / total requests, **excluding**:

- 4xx client errors (caller's side)
- Requests with revoked or expired credentials
- Requests shed by upstream capacity protection (see rate-limits)

Measurement window: rolling calendar month.

## Remediation

If SLO is breached in a calendar month, reach builders@swiggy.in for remediation options. In v1 remediation is handled on a partnership basis. Enterprise contracts include explicit credit schedules.

Builders Club

Cook on Swiggy's MCP platform. Open to developers, startups, and enterprises.

builders@swiggy.in

#### Program

- For Developers
- For Enterprises
- How It Works
- Benefits

#### Resources

- Guidelines
- FAQ
- Apply
- llms.txt

#### Legal

- Privacy Policy
- Terms and Conditions

© 2026 Swiggy. All rights reserved.

Swiggy Builders Club — MCP Partnership Program

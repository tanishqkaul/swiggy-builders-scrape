# Power an agent platform | Swiggy Builders Club

**URL:** https://mcp.swiggy.com/builders/docs/start/enterprise/

---

# Power an agent platform

White-glove onboarding for agent-platform operators running Swiggy on behalf of many end users.

For agent-platform operators - voice assistants, in-app agents, conversational commerce surfaces - where your users are Swiggy users, but via your product. Not for individual developers (that's Developer).

## Who this track is for

- **Voice assistants**: smart speakers, automotive voice agents, and TV voice surfaces.
- **Messaging-driven commerce**: WhatsApp-style replenishment agents, in-chat ordering.
- **Lifestyle apps with agents**: fitness, meal-planning, concierge products where Swiggy is one of many commerce backends.
- **Enterprise SaaS**: procurement, corporate meal ordering.

If that sounds like you, the table below is your track.

| What you get | What you owe |
| --- | --- |
| Delegated OAuth for multi-tenant user flows | Valid end-user consent per DPDP |
| Custom capacity ceilings scoped to your expected traffic | Responsible traffic shaping; honour `Retry-After` once rate limiting ships at the MCP layer |
| Dedicated engineering contact + escalation path | Security review; see Access |
| Co-branding options ("Powered by Swiggy") | Follow brand guidelines (shared at onboarding) |
| Partner attribution + engagement signals back to you | Keep attribution fidelity (no stripping) |
| Pre-production staging environment with seed data | Observe staging-only guardrails |

## How onboarding works

1. **Apply** at /access marking yourself as a platform operator. Include expected user base (size, geographies), surfaces (voice/chat/app), and peak QPS.
2. **Intro call** - 30 minutes with Swiggy's partnerships team to scope fit.
3. **Architecture review** - 30-60 minutes with engineering. Covers delegated auth, rate-limit targets, observability handoff, brand integration.
4. **Partner contract** - commercial terms, compliance attestations, co-branding rights. Turnaround: 4+ weeks for enterprise-specific clauses.
5. **Staging access** - your engineering team gets credentials and walks through Delegated auth.
6. **Production cutover** - after a partner-specific launch checklist (rate-limit uplift, incident-response handoff, co-branding assets).

## The hard parts you'll care about

- **Delegated auth at scale** - OAuth 2.1 on-behalf-of flow for brokering Swiggy tool calls for thousands or millions of end users, with per-user consent and Swiggy holding the PII.
- **Rate limits** - default ceilings don't fit platform traffic. Negotiated per-partner based on expected QPS and daily volume.
- **SLA** - 99.9% uptime target on production MCP endpoints; latency targets per tool class.
- **Data handling** - Swiggy is the data fiduciary under DPDP 2023. Your product processes Swiggy data only within the contracted scope.
- **Voice-first response shaping** - for TTS and in-car surfaces, rich card widgets don't help. Design tool prompts for concise, imperative responses.

## Get in touch

- Primary: builders@swiggy.in with subject line "Platform partner - [your company]"
- Urgent (existing partner incident): your designated engineering contact + security@swiggy.in if security-related

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

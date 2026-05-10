# Access & Onboarding | Swiggy Builders Club

**URL:** https://mcp.swiggy.com/builders/docs/operate/access/

---

# Access & onboarding

Apply for production access - what we look for, what you provide, turnaround.

Swiggy MCP is **invite-based in v1**. We review every application. Good integrations get production credentials fast; unclear ones get follow-up questions.

## Build locally first, then send us a video

You don't need credentials to start. Wire Swiggy MCP into your agent against a local dev stub (or use staging once you have access), build the experience end-to-end on `http://localhost`, and record a short screen capture of it working. Walking us through a real flow video is the fastest way to get from application to allowlist - it tells us more in a minute than a paragraph of intent does.

When you apply at /access, include a link to the video (Loom, Drive, YouTube unlisted - anything we can play). Send to **builders@swiggy.in** if your application form doesn't have a video field.

## Who can apply

- **Developers** building an agent or product that will serve real users on Swiggy tools.
- **Platform operators** (voice assistants, ambient commerce surfaces) brokering Swiggy for their end users - see Enterprise for the white-glove path.
- **Skill authors** contributing to Real World Skills with Swiggy as a target provider.

## What we look for

- A **concrete use case** with real end users (not a sandbox demo).
- **Alignment with Swiggy's consumer experience** - agents that respect the user, confirm orders, and don't surprise them.
- **Technical readiness** - you can complete OAuth, handle 401/429, retry safely.
- **Responsible traffic patterns** - you estimate your QPS and agree to honour rate limits.
- **Security baseline** - HTTPS redirect URIs, no PII storage beyond what you need.

For enterprise partners, additional review covers commercial terms, security posture (SOC 2 preferred), compliance attestations, and platform-specific requirements.

## What you provide

When you apply at /access, we ask for:

1. **Integration name & organization** - short, human-readable.
2. **Redirect URIs** - HTTPS, exact-match. `http://localhost` allowed for local dev; platform schemes (e.g. `alexa://`, `googleassistant://`) allowed case-by-case.
3. **Servers requested** - any of `food`, `instamart`, `dineout`. Access is granted per-server by binding your `client_id` to the server allowlist; v1 scopes (`mcp:tools`, `mcp:resources`, `mcp:prompts`) apply uniformly across whatever you're allowlisted for.
4. **Expected volume** - rough estimate of orders/day and tool calls/day.
5. **Use case** - one paragraph describing what you're building.
6. **Primary technical contact** - email that reaches an engineer.
7. **For enterprise**: security attestations available (SOC 2, ISO 27001), expected peak QPS, surfaces (voice/chat/app), end-user geography.

## Turnaround

- **Developers**: staging credentials are issued during application review; production follows after a working staging integration.
- **Platform operators / enterprise**: variable - typically 4+ weeks because commercial terms are negotiated per-partner.

## What you get

- A `client_id` - public identifier used in your OAuth flow.
- Staging access at `mcp-staging.swiggy.com/{server}` - same shape as production, backed by seeded data (no real orders).
- Production access once staging has been green for ≥ 48 hours.
- Contact details for your designated engineering point of contact.
- Access to the `builders@swiggy.in` support channel.
- Enterprise only: dedicated Slack channel, per-partner dashboards, co-branding assets.

## What we ask of you

- Complete the technical checklist in Ship to production before your first real-user call.
- Keep your security contact up-to-date.
- Notify us 7 days ahead of any major traffic event (launch, campaign) so we can provision capacity.
- Treat Swiggy session ids as a support identifier, not a business identifier - don't key your internal records on them.

## Revocation

Credentials can be revoked without notice for:

- Security incidents involving your integration.
- Traffic patterns indicative of abuse (scraping, credential stuffing, bulk catalogue export).
- Material violations of the partner terms (covered separately at contract sign).

We'll always try to reach you first if there's ambiguity.

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

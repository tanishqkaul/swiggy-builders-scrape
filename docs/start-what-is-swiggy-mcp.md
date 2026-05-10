# What is Swiggy MCP? | Swiggy Builders Club

**URL:** https://mcp.swiggy.com/builders/docs/start/what-is-swiggy-mcp/

---

# What is Swiggy MCP?

What Swiggy Builders Club offers, who it's for, and when to use it.

Swiggy Builders Club exposes Swiggy's commerce platform as **MCP servers** - the open standard (Model Context Protocol) that AI agents speak to external tools. One protocol, three servers, 35 tools, zero vendor lock-in.

## The three servers

| Server | Endpoint | What it does | Tools |
| --- | --- | --- | --- |
| **Food** | `mcp.swiggy.com/food` | Restaurant discovery, menus, ordering, tracking | 14 |
| **Instamart** | `mcp.swiggy.com/im` | Quick-commerce grocery | 13 |
| **Dineout** | `mcp.swiggy.com/dineout` | Table reservations | 8 |

Each server is independent. Wire one, two, or all three - they don't share carts, orders, or sessions.

## Who it's for

- **Agent developers** building with OpenAI Agents SDK, Anthropic SDK, LangGraph, Vercel AI SDK, Mastra, PydanticAI, CrewAI, or Google ADK. You ship an agent that talks to Swiggy as a tool provider.
- **Agent platforms** running at scale - voice assistants, in-app agents, conversational commerce - that broker Swiggy on behalf of many end users. You need delegated auth and production rate limits.
- **AI-client users** of Claude Desktop, ChatGPT, Cursor, VS Code, or Windsurf who want Swiggy available as a tool inside their existing client. No code - just a config paste.

## When MCP fits (and when it doesn't)

MCP shines when an agent needs to **discover and reason across multiple tools at runtime**. The LLM sees tool schemas, decides which to call, orchestrates multi-step flows like search → menu → cart → checkout. That's Swiggy's sweet spot.

If you're embedding a fixed Swiggy widget into a SaaS product without any agent involvement - a "reorder my last Instamart basket" button - you want Swiggy's regular APIs, not MCP. This site is MCP-only.

## What you get out of the box

- **OAuth 2.1 with PKCE** - the same auth flow Claude Desktop and Cursor use natively.
- **Streamable HTTP transport** - one URL per server, standard JSON-RPC.
- **Session auth** - no passing user credentials as tool arguments.
- **Stable error taxonomy** - canonical error codes your code can branch on.
- **Versioning contract** - 6-month deprecation windows (see versioning).

## What you're signing up for

- **India-only user base** - Swiggy serves Indian consumers. No cross-border data flow, no US/EU residency.
- **Whitelist onboarding** - production access is invite-based today; see Access.
- **Partner contract** - SLA, rate limits, data handling described in Operate. Some clauses are negotiated per-partner.

## Where to go next

- Build your first agent: Developer quickstart.
- Running an agent platform: Enterprise onboarding.
- Just want Swiggy in Claude Desktop: Consumer install.
- Poke at the tool catalogue: Reference.

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

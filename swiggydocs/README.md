# Swiggy Builders Club - Complete Website Scrape

This folder contains a complete scrape of the Swiggy Builders Club website (mcp.swiggy.com) saved as markdown files.

## Overview

Swiggy Builders Club is an MCP (Model Context Protocol) platform exposing Swiggy's commerce APIs:
- **Food**: Restaurant discovery, menus, ordering, tracking (14 tools)
- **Instamart**: Quick-commerce grocery (13 tools)
- **Dineout**: Table reservations (8 tools)

## Structure

```
swiggy-builders-scrape/
├── README.md (this file)
├── INDEX.md (comprehensive site index)
└── docs/
    ├── index.md (homepage)
    ├── blog.md
    ├── faq.md
    ├── for-developers.md
    ├── for-enterprises.md
    ├── get-access.md
    ├── guidelines.md
    ├── how-it-works.md
    ├── benefits.md
    └── llms.txt
    ├── docs-index.md
    ├── what-is-swiggy-mcp.md
    ├── authenticate.md
    ├── start-start.md
    ├── start-developer.md
    ├── start-consumer.md
    ├── build.md
    ├── build-recipes-order-food.md
    ├── build-recipes-order-groceries.md
    ├── build-recipes-book-table.md
    ├── build-recipes-combined.md
    ├── build-agent-patterns-multi-turn-state.md
    ├── build-agent-patterns-voice-vs-chat.md
    ├── build-ship-to-production.md
    ├── build-widgets.md
    ├── reference.md
    ├── error-codes.md
    ├── reference-dineout-book-table.md
    ├── reference-dineout-create-cart.md
    ├── reference-dineout-get-available-slots.md
    ├── reference-dineout-get-booking-status.md
    ├── reference-dineout-get-restaurant-details.md
    ├── reference-dineout-get-saved-locations.md
    ├── reference-dineout-report-error.md
    ├── reference-dineout-search-restaurants-dineout.md
    ├── reference-dineout-verify-otp.md
    ├── operate.md
    ├── operate-access.md
    ├── operate-changelog.md
    ├── operate-data-and-compliance.md
    ├── operate-rate-limits.md
    ├── operate-sla.md
    ├── operate-support.md
    └── operate-versioning.md
```

## Quick Navigation

### Getting Started
- [What is Swiggy MCP?](./docs/what-is-swiggy-mcp.md)
- [Developer Quickstart](./docs/start-developer.md)
- [Authenticate (OAuth 2.1 with PKCE)](./docs/authenticate.md)

### Building Agents
- [Build Overview](./docs/build.md)
- [Order Food End-to-End](./docs/build-recipes-order-food.md)
- [Order Groceries End-to-End](./docs/build-recipes-order-groceries.md)
- [Book a Table](./docs/build-recipes-book-table.md)
- [Voice vs Chat](./docs/build-agent-patterns-voice-vs-chat.md)

### API Reference
- [Reference Overview](./docs/reference.md)
- [Error Codes](./docs/error-codes.md)
- [Dineout API Tools](./docs/reference-dineout-book-table.md)

### Operations
- [Operate Overview](./docs/operate.md)
- [Access & Onboarding](./docs/operate-access.md)
- [Rate Limits](./docs/operate-rate-limits.md)
- [SLA & Uptime](./docs/operate-sla.md)
- [Support](./docs/operate-support.md)

## Stats

- **Total Pages**: 35+ documentation pages
- **Total Tools**: 35 across 3 MCP servers
- **Frameworks Supported**: OpenAI Agents SDK, Anthropic SDK, LangGraph, Vercel AI SDK, Mastra, PydanticAI, CrewAI, Google ADK

## Contact

- **Email**: builders@swiggy.in
- **Security**: security@swiggy.in

---
*Scraped from https://mcp.swiggy.com/builders*

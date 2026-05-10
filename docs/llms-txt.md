# Swiggy Builders Club

> Swiggy Builders Club is the ecosystem program around Swiggy's MCP stack — Food, Instamart, and Dineout. Build AI agents, copilots, and integrations on top of 35+ tools across 3 MCP servers.

> Each link below points at a `.md` twin of the page. Fetch the `.md` for clean markdown; fetch the page URL (without `.md`) for the rendered HTML version.

## Docs

- [Multi-turn cart state](https://mcp.swiggy.com/builders/docs/build/agent-patterns/multi-turn-state.md): Carrying cart identity across user turns on a stateless protocol.
- [Voice vs chat](https://mcp.swiggy.com/builders/docs/build/agent-patterns/voice-vs-chat.md): The same Swiggy tool, different response contracts. Design for TTS and rich cards separately.
- [Build](https://mcp.swiggy.com/builders/docs/build/index.md): Recipes and patterns for shipping agents that use Swiggy MCP.
- [Book a table](https://mcp.swiggy.com/builders/docs/build/recipes/book-a-table.md): Dineout journey - find a restaurant, check availability, reserve.
- [Plan my evening (combined)](https://mcp.swiggy.com/builders/docs/build/recipes/combined.md): One user ask, two MCP servers - Food delivery and Dineout reservations composed in a single agent turn.
- [Order food end-to-end](https://mcp.swiggy.com/builders/docs/build/recipes/order-food.md): The canonical 7-tool Food journey - from address to placed order to delivery tracking.
- [Order groceries end-to-end](https://mcp.swiggy.com/builders/docs/build/recipes/order-groceries.md): Full Instamart journey - find products, build a cart, checkout, track delivery.
- [Ship to production](https://mcp.swiggy.com/builders/docs/build/ship-to-production.md): Retries, observability, and the go-live checklist.
- [Widgets](https://mcp.swiggy.com/builders/docs/build/widgets.md): Render-ready UI fragments that Swiggy MCP servers can return alongside tool responses.
- [Swiggy Builders Club](https://mcp.swiggy.com/builders/docs/index.md): Build commerce into your AI agent. Food, Instamart, and Dineout - 35 MCP tools, India-first.
- [Access & onboarding](https://mcp.swiggy.com/builders/docs/operate/access.md): Apply for production access - what we look for, what you provide, turnaround.
- [Changelog](https://mcp.swiggy.com/builders/docs/operate/changelog.md): What shipped when, grouped by release.
- [Data & compliance](https://mcp.swiggy.com/builders/docs/operate/data-and-compliance.md): DPDP 2023 posture, data residency, consent, no-PII stance, certifications.
- [Operate](https://mcp.swiggy.com/builders/docs/operate/index.md): The partner contract - SLA, rate limits, data handling, versioning, support.
- [Rate limits](https://mcp.swiggy.com/builders/docs/operate/rate-limits.md): How Swiggy MCP handles abusive traffic today, the quotas we plan to advertise, and how to request a larger allocation.
- [SLA & uptime](https://mcp.swiggy.com/builders/docs/operate/sla.md): Service-level objectives for Swiggy MCP endpoints.
- [Support](https://mcp.swiggy.com/builders/docs/operate/support.md): How to reach us, incident severities, co-branding, and agent error reporting.
- [Versioning](https://mcp.swiggy.com/builders/docs/operate/versioning.md): SemVer commitment, deprecation window, how we announce breaking changes.
- [book_table](https://mcp.swiggy.com/builders/docs/reference/dineout/book_table.md): Swiggy Dineout (Reservations): Book a table at a restaurant for a specific time slot. Only supports FREE reservations (isFree=true, bookingPrice=0). Paid deals will be rejected. Creates a cart then p...
- [create_cart](https://mcp.swiggy.com/builders/docs/reference/dineout/create_cart.md): Swiggy Dineout: Create a cart for TABLE BOOKING or bill payment. For booking (DEAL_TICKET_PURCHASE): requires restaurant ID, slot details, and guest count. Validates billToPay = 0 and skipPayment = t...
- [get_available_slots](https://mcp.swiggy.com/builders/docs/reference/dineout/get_available_slots.md): Swiggy Dineout (Reservations): Check available time slots for TABLE BOOKING at a restaurant. Returns slots across up to 7 days from the requested date. Shows breakfast, lunch, and dinner slots with a...
- [get_booking_status](https://mcp.swiggy.com/builders/docs/reference/dineout/get_booking_status.md): Get booking status and details for a dineout order. Returns restaurant name, date, time, guests, deal title, and status. Example: "What is the status of my booking?" → Call with order ID.
- [get_restaurant_details](https://mcp.swiggy.com/builders/docs/reference/dineout/get_restaurant_details.md): Swiggy Dineout: Get details about a specific restaurant for TABLE BOOKING. Returns ratings, deals, timings, address. Use restaurant ID from search_restaurants_dineout results. Use same coordinates th...
- [get_saved_locations](https://mcp.swiggy.com/builders/docs/reference/dineout/get_saved_locations.md): Swiggy Dineout: Get user's saved addresses for restaurant search. Returns address IDs that can be passed to search_restaurants_dineout.

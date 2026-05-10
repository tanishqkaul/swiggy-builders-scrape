# Delegated Auth | Swiggy Builders Club

**URL:** https://mcp.swiggy.com/builders/docs/start/enterprise/delegated-auth/

---

# Delegated auth

OAuth 2.1 on-behalf-of flow for multi-tenant platforms serving end users at scale.

Platform operators don't authenticate as themselves - they authenticate **on behalf of** each end user. Your user, Swiggy's account, your UI. Swiggy holds the PII; you hold the scoped session. This page is the contract.

## The principle

Swiggy remains the data fiduciary under DPDP 2023. End users authorize Swiggy access through your product via OAuth 2.1 with PKCE. Your platform receives a per-user access token scoped to a named `client_id`. You never see the user's Swiggy password, OTP, or raw PII beyond what tool responses return.

## The flow

```
┌────────────┐      ┌─────────────────┐     ┌────────────────┐     ┌─────────────┐
│  End user  │      │  Your platform   │     │  Swiggy OAuth  │     │  Swiggy     │
│ (voice /   │      │   (Alexa /       │     │  server        │     │  identity   │
│  chat /    │      │    Gemini /      │     │                │     │  service    │
│  in-app)   │      │    platform)     │     │                │     │             │
└─────┬──────┘      └────────┬─────────┘     └────────┬───────┘     └──────┬──────┘
      │                      │                         │                    │
      │  "Order food"        │                         │                    │
      ├─────────────────────►│                         │                    │
      │                      │  Detect: user needs     │                    │
      │                      │  Swiggy authorization   │                    │
      │                      │                         │                    │
      │  Open link / card:   │                         │                    │
      │  "Connect Swiggy"    │                         │                    │
      │◄─────────────────────┤                         │                    │
      │                      │                         │                    │
      │  /auth/authorize?                              │                    │
      │  client_id=YOU&state=...&code_challenge=...    │                    │
      ├────────────────────────────────────────────────►│                   │
      │                      │                         │  Phone + OTP       │
      │                      │                         ├───────────────────►│
      │                      │                         │◄───────────────────┤
      │  Redirect to         │                         │                    │
      │  your callback URL   │                         │                    │
      │  with authorization  │                         │                    │
      │  code                │                         │                    │
      │◄────────────────────────────────────────────────┤                   │
      │                      │                         │                    │
      │                      │  POST /auth/token       │                    │
      │                      │  + code_verifier        │                    │
      │                      ├────────────────────────►│                    │
      │                      │◄────────────────────────┤                    │
      │                      │  access_token           │                    │
      │                      │  (scoped, 5 days)       │                    │
      │                      │                         │                    │
      │                      │  Call Swiggy MCP tool   │                    │
      │                      │  on behalf of user      │                    │
      │                      ├────────────────────────►│                    │
```

## Implementation

### 1. Pre-register your platform

At onboarding, Swiggy issues your platform:

- A `client_id`
- An allowlisted set of `redirect_uri` values (exact-match HTTPS, or platform-specific schemes like `googleassistant://`, `alexa://`, `jio-hello://`)
- An allowlisted set of Swiggy MCP servers - which of `food`, `instamart`, `dineout` your `client_id` is approved to call. Access is `client_id`-scoped, not scope-scoped.

### 2. Initiate authorization per user

Generate a fresh PKCE verifier/challenge pair for each user session:

```javascript
import crypto from "node:crypto";
 
const codeVerifier = crypto.randomBytes(32).toString("base64url");
const codeChallenge = crypto
  .createHash("sha256")
  .update(codeVerifier)
  .digest("base64url");
```

Send the user to:

```
https://mcp.swiggy.com/auth/authorize?
  response_type=code&
  client_id=<your-client-id>&
  redirect_uri=<your-callback>&
  code_challenge=<challenge>&
  code_challenge_method=S256&
  state=<per-user-csrf-token>&
  scope=mcp:tools mcp:resources
```

The user completes phone + OTP on Swiggy's domain, then is redirected to your callback with an authorization `code`.

### 3. Exchange code for token

POST to `/auth/token`:

```javascript
const response = await fetch("https://mcp.swiggy.com/auth/token", {
  method: "POST",
  headers: { "Content-Type": "application/x-www-form-urlencoded" },
  body: new URLSearchParams({
    grant_type: "authorization_code",
    client_id: YOUR_CLIENT_ID,
    code: authorizationCodeFromCallback,
    redirect_uri: YOUR_CALLBACK_URL,
    code_verifier: codeVerifierGeneratedEarlier,
  }),
});

const { access_token, expires_in } = await response.json();
// access_token is a JWT; expires_in is typically 5 days (432000 seconds)
```

### 4. Call MCP tools on behalf of user

Include the access token in the Authorization header:

```javascript
const mcpResponse = await fetch("https://mcp.swiggy.com/food", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${access_token}`,
    "Mcp-Session-Id": generateSessionId(), // your internal session tracking
  },
  body: JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: {
      name: "search_restaurants",
      arguments: { addressId: "addr_123", query: "biryani" },
    },
  }),
});
```

## Token lifecycle

- **Access tokens** expire in 5 days (configurable per-partner for enterprise)
- **Refresh tokens** are not issued in v1.0; re-authorization required
- **Token storage** is your responsibility; treat as sensitive credentials
- **Token revocation** can be triggered by users in their Swiggy app or by Swiggy for policy violations

## Security requirements

- PKCE is mandatory; implicit flow is not supported
- `state` parameter must be verified to prevent CSRF
- `redirect_uri` must match exactly what was registered
- Tokens must be stored encrypted at rest
- Token transmission must be over TLS 1.3

## Multi-tenancy considerations

For platforms serving many users:

- Each user gets their own access token
- Store tokens keyed by your internal user ID
- Implement token refresh logic (in v1.1 when refresh tokens ship)
- Monitor for token expiry and re-auth triggers

## Get help

Delegated auth is complex. Enterprise partners get dedicated support:

- Email: builders@swiggy.in
- Subject: "Delegated auth help - [your company]"
- Include: client_id, error details, timestamp, request ID if available

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

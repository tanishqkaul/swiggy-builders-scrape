# PRD-005: One-Tap Order Flow

**Version:** 1.0
**Status:** Approved

---

## Goal

Design the zero-friction ordering experience. From notification tap to confirmed order: < 30 seconds, < 3 taps, no browsing.

---

## The Flow

```
[Push notification received]
  ↓ user taps
[App opens / foregrounds]
  ↓
[OrderConfirmSheet slides up — 350ms animation]
  ↓
[User sees: item, restaurant, price, ETA]
  ↓ user taps "Confirm"
[Loading spinner — order being placed — < 3s]
  ↓
[Success state: order confirmed, Swiggy order ID shown]
  ↓
[Sheet auto-dismisses after 3 seconds]
```

**Target time: notification tap → confirmed order ≤ 30 seconds.**
**Target taps: 1 (notification) + 1 (Confirm) = 2 taps total.**

---

## Pre-Building the Cart

The pre-built cart is why this feels instant. It happens 45 minutes before the notification fires:

```python
# order_service.py
async def prebuild_cart(prediction: PredictionResult, user_id: str) -> str:
    # 1. Verify item is available right now
    availability = await swiggy_mcp.check_availability(
        item_id=prediction.item_id,
        restaurant_id=prediction.restaurant_id,
        user_location=user.location
    )
    if not availability.is_available:
        # Try next-best item in same category
        prediction = await find_alternative(prediction.category, user)

    # 2. Build cart via Swiggy MCP
    cart = await swiggy_mcp.build_cart(
        item_id=prediction.item_id,
        restaurant_id=prediction.restaurant_id,
        quantity=1,
        address_id=user.default_address_id
    )

    # 3. Store in Redis with TTL
    cart_key = f"cart:{prediction.id}"
    await redis.setex(cart_key, 5400, cart.to_json())  # 90-min TTL

    return cart_key
```

---

## OrderConfirmSheet Content

```
┌──────────────────────────────────────────────────┐
│  ────  (drag handle)                              │
│                                                    │
│  [Item image — 120x120, rounded-xl, centered]     │
│                                                    │
│  Chicken Biryani                    [text-xl Bold] │
│  Behrouz Biryani · Koramangala      [text-sm gray] │
│                                                    │
│  ┌────────────────────────────────┐               │
│  │  Delivery by 8:20 PM  •  ₹299  │  [info pill]  │
│  └────────────────────────────────┘               │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │          Confirm order           [ring timer] │ │
│  └──────────────────────────────────────────────┘ │
│  "CravingsAPI was 87% confident about this one."  │
│                                                    │
│          Cancel                                    │
└──────────────────────────────────────────────────┘
```

**Countdown ring:** Animated circular stroke around the Confirm button, counting down from 5 seconds. Disabled by default in v1 (auto-confirm is opt-in in Settings). When disabled, ring animation still plays, but does not auto-submit.

**Price display:** Always fetched fresh at sheet open (not from pre-built cart cache) to show current price. If price has changed since prediction: "Price updated: ₹349" with amber color.

---

## Cart States

### State A: Cart Ready (happy path)
- Cart pre-built and in Redis
- Sheet loads instantly with full item details
- Confirm button active immediately

### State B: Cart Building (on-demand)
- Cart TTL elapsed, or pre-build failed
- Sheet shows skeleton of item details
- "Preparing your order…" text below item name
- Confirm button: spinner, disabled
- On cart ready (≤ 5s): swap skeleton for real content, enable Confirm
- If build takes > 8s: show error state

### State C: Item Unavailable
- Pre-build failed because item is sold out
- Show: "Chicken Biryani isn't available right now."
- Offer: "Order from [restaurant]?" → opens Swiggy app on restaurant page
- Alternative suggestion: "Try [next-best item]?" → rebuild cart for alternative

### State D: Order Success
```
[Lottie confetti animation — 1.5s]

✓ Order placed!

Chicken Biryani from Behrouz Biryani
Arriving by 8:20 PM

[Track in Swiggy →]
```
Haptic: `.impactOccurred(.heavy)`
Auto-dismiss after 3 seconds → return to home screen.

### State E: Order Failure
```
Something went wrong placing your order.

[Try again]   [Open Swiggy directly →]
```
"Open Swiggy directly" deep links to Swiggy app on the restaurant page.

---

## Confirm → Cancel Behavior

**Cancel during countdown:** Sheet dismisses. Prediction outcome marked `dismissed`. No retry — user made a decision.

**Cancel after tapping Confirm (order in progress):** If Swiggy MCP has not yet returned → cancel the HTTP request, show "Cancelled." If MCP already confirmed order → show "Order placed — cancel in Swiggy app." with deep link.

---

## Edge Cases

| Case | Handling |
|---|---|
| User taps notification but already ate | Cancel flow. Next prediction cycle adapts based on time-of-day context. |
| Two notifications arrive close together | Second replaces first in notification tray. Tapping second shows its cart. First cart expires normally. |
| User taps 3 hours after notification | Cart expired → State B (rebuild) → if restaurant closed: State C. |
| Order placed but Swiggy callback delayed | Show "Order submitted" (optimistic) → poll order status every 30s → update to "confirmed" when Swiggy confirms |
| Address not set | Pre-build stage fetches user's default Swiggy address via MCP → if none found → prompt: "Add a delivery address in Swiggy first" |
| Low balance / payment failure | Swiggy MCP returns payment error → show "Payment failed" + "Update payment in Swiggy" deep link |

---

## Swiggy MCP Order Placement

```python
async def place_order(cart_id: str, user_id: str) -> OrderResult:
    cart_json = await redis.get(f"cart:{cart_id}")
    if not cart_json:
        cart_json = await prebuild_cart_on_demand(...)

    cart = SwiggyCart.parse_raw(cart_json)

    response = await swiggy_mcp.post("/food/cart/place", json={
        "cart_id": cart.swiggy_cart_id,
        "payment_method": cart.default_payment_method,
        "address_id": cart.address_id,
    })

    await db.orders.insert({
        "user_id": user_id,
        "swiggy_order_id": response["order_id"],
        "prediction_id": cart_id,
        "item_name": cart.item_name,
        "total_amount": response["total_amount"],
        "status": "placed",
    })

    await db.predictions.update(
        where={"id": cart_id},
        set={"outcome": "ordered", "order_id": response["order_id"]}
    )

    return OrderResult(order_id=response["order_id"], eta=response["eta"])
```

---

## Payment Handling

CravingsAPI never handles payment directly. All payment is managed by Swiggy:
- Pre-built cart uses user's default payment method stored in Swiggy
- Swiggy MCP order placement uses Swiggy's existing payment flow
- If payment fails: surface Swiggy's error code, deep link to Swiggy for resolution
- We never see card details, UPI PINs, or CVVs

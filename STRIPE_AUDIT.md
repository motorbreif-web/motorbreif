# Stripe price and webhook audit

**Audit date:** 28 October 2026  
**EV price amendment:** 2 November 2026; at the owner's request, the Essential comparison changed from £12.99 to £4.99 (499p). No new Stripe Session or completed payment was created for this price update.  
**Project:** Motor B / motorbreif  
**Scope:** standard vehicle-report Checkout and report verification; EV test Checkout; Stripe metadata; webhook signature, mode and idempotency behavior; runtime key separation.

## Executive summary

The active server-side prices are standard vehicle report **£9.99 GBP (999 pence)** and Essential EV comparison **£4.99 GBP (499 pence)**. The EV checkout is explicitly test-only, disables promotions, and does not generate a report. The standard Checkout had a verification gap: its current metadata marker could bypass line-item and amount verification. That path is now hardened so every paid report must match the expected single GBP vehicle-report item and 999-pence base price. Preview/development now accepts only Stripe test keys; production accepts only live keys. A valid webhook from the wrong Stripe mode is acknowledged but not processed or recorded.

No card was entered, no payment completed, no UKVD lookup or report fulfillment was triggered, and no webhook delivery was simulated. The public site was not published.

## Product and price controls

| Product | Server product identifier | Base amount | Checkout behavior |
|---|---|---:|---|
| Standard vehicle report | `vehicle_report` | £9.99 / 999p | One GBP payment line item. Promotion codes remain enabled; a valid discount can lower the final total, but the session and line-item totals must match and cannot exceed the base amount. |
| Essential EV comparison | `ev_comparison_test` | £4.99 / 499p | Preview/test keys only, one GBP item, promotions disabled, exact 499p total. No UKVD call or report fulfillment. |
| EV Buyer Intelligence | Preview card only | £7.99 | No Checkout creation path. |
| Premium Used EV Report | Preview card only | £12.99 | No Checkout creation path. |

The shared amounts and EV labels are in `shared/products.mjs:1-6`. The test-only EV creation and session verification are in `server/ev-checkout.js:8-29,37-94,101-127`.

## Findings and changes

### 1. Standard report amount could previously bypass verification — fixed

`server/index.js` previously accepted a recognized `metadata.product=vehicle_report` marker immediately, without retrieving line items or checking the price. Its fallback branch checked only the item subtotal. A paid session with that marker could therefore pass the product verifier without proving the expected amount.

The shortcut has been removed. `server/index.js:30-32` now always retrieves Checkout line items and calls `isValidMotorBVehicleReportSession` in `server/stripe-validation.js:19`. That validator requires a paid `payment` session, GBP, the normalized registration, one expected vehicle-report line item, a 999p unit price and subtotal, and a final line-item total matching the Stripe Session total and not exceeding the 999p base. This preserves the existing promotion-code feature: discounts may reduce the amount, but a mismatched or higher total is rejected. EV test product metadata cannot qualify as a vehicle report.

### 2. Preview could previously use a live key for the standard product — fixed

Before this audit, the standard Stripe client accepted any configured key outside `NODE_ENV=production`. Preview currently uses a test key, but a future live key mistakenly placed in the Preview scope could have opened a real Checkout.

`server/stripe-validation.js:7-12` now permits only `sk_test_`/`rk_test_` keys outside production and only `sk_live_`/`rk_live_` keys in production. The production Docker image sets `NODE_ENV=production` (`Dockerfile:21-22`). Unit tests cover both accepted and rejected key/runtime combinations.

### 3. Webhook handling and fulfillment boundary

`POST /api/stripe/webhook` is registered before JSON parsing and verifies the Stripe signature over the raw body (`server/index.js:36-44`). It now checks that `event.livemode` matches the runtime mode (`server/index.js:46`). Marked EV test events are acknowledged without writes (`server/index.js:49`; classifier in `server/ev-checkout.js:32-35`). Other signed, mode-matched subscribed events are recorded by ID/type/object ID; `INSERT IGNORE` on the event-ID primary key makes redelivery a database no-op (`server/report-store.js:73-79`). The handler does **not** fulfill reports.

The paid standard report is instead generated on the customer return path: `/api/report` retrieves and re-verifies the Stripe Session before calling report generation (`server/index.js:153-199`). This has been documented accurately in `README.md:31-37`. **Operational limitation:** if a customer closes Checkout before returning to `/report`, the webhook alone will not generate the report or start the report email. Webhook-driven fulfillment was not introduced in this audit because it needs a separately approved idempotent delivery/retry design for potentially billable UKVD lookups.

The managed Stripe integration subscribes to six event types: `payment_intent.succeeded`, `payment_intent.payment_failed`, `checkout.session.completed`, and the three `customer.subscription.*` lifecycle events. Subscription events are acknowledged/recorded; the site currently has no subscription product.

### 4. EV test metadata and fulfillment boundary

The EV test Checkout fixes the amount and product on the server, disables promotion codes, and sets `app`, `brand`, `product`, and `test_only` on both Checkout Session and PaymentIntent creation parameters (`server/ev-checkout.js:68-94`). Its verification checks the Session and one line item against 499p GBP and those markers. The route returns only a status-aware test summary and `reportGenerated: false` (`server/ev-checkout.js:101-127`).

The existing unpaid EV test Session was verified in Stripe test mode at 1299p GBP with `product=ev_comparison_test` and `test_only=true` before the 2 November price amendment. It is historical evidence only and does not reflect the active £4.99 price. No PaymentIntent existed because no payment method was entered; therefore the PaymentIntent metadata setting is confirmed in source but **not observed on an actual PaymentIntent**. No new 499p EV Checkout Session, EV webhook or payment was created or tested for this price update.

## Verification performed

- `node --test server/*.test.js`: **12 passed, 0 failed**.
- `node --check` passed for the server and validation modules; `git diff --check` was clean.
- A newly created, unpaid standard test Checkout Session was read back from Stripe: payment mode, GBP, 999p subtotal/total, one quantity-one vehicle-report line item at 999p, `product=vehicle_report`, and immediate-supply consent metadata present. Its registration was not included in this report.
- The standard and EV unpaid test sessions each returned HTTP 402 from `/api/report`; neither produced a report.
- The Preview health endpoint returned success; the active Preview runtime reported test-mode Stripe without revealing key values.
- The active website and server source use the shared 499p Essential price, including Checkout validation and test assertions. The former amount is retained only in this audit as explicitly historical session evidence; £12.99 remains a separate non-purchasable Premium preview tier.

## Deliberate limits

The audit did not complete a test purchase or claim that a successful payment, PaymentIntent event, webhook delivery, production key, live customer charge, or UKVD report was tested. The Checkout Sessions remain unpaid. The EV comparison remains test-only; the other EV tiers are not purchasable. The public deployment remains unchanged: automatic publication is enabled, and the outstanding business/legal and UKVD production-readiness blockers still apply.

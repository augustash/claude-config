---
name: The browser return and the webhook do the same work twice
description: An express wallet payment can end on Drupal's generic error page while the order in fact placed, and leave one intent recorded as two payments so the order's balance reads double what Stripe took. onReturn() and processWebHook() race, and three things neither may do twice are unguarded.
metadata:
  type: reference
---

# The browser return and the webhook do the same work twice

Two symptoms, one cause, and neither points at the other:

- A shopper finishing an **express wallet payment on a phone** lands on *"The
  website encountered an unexpected error"*. Refreshing shows the confirmation
  page — the order placed, the money was taken, and only the shopper thinks it
  failed.
- The order carries **two payments for one intent**, so its recorded balance is
  double what Stripe actually took.

Nobody is billed twice: it is one intent and one charge. The damage is in
Drupal's own numbers, which is what reconciliation and any downstream export
read.

## Why

`onReturn()` and `processWebHook()` do substantially the same work, and only one
of them took a lock. `processWebHook()` loads the order with `loadForUpdate()`;
`onReturn()` did not, so it worked on an order the webhook was in the middle of
placing and its own save raised `OrderLockedSaveException` — at the shopper.

**Express is where the two meet**, because a wallet confirms the intent
server-side: Stripe can deliver `payment_intent.succeeded` before the browser
has finished coming back. The slower the connection, the more reliably the
webhook wins — which is exactly why it presents as a phone-only problem and
never reproduces on a desktop on office wifi.

Taking the same lock in `onReturn()` (released in a `finally`, since the method
leaves by *throwing* its redirect) stops them overlapping. It does not stop them
**both running in turn**, so each thing that must not happen twice needs
guarding where it happens:

| Repeated | Consequence |
| --- | --- |
| `handlePaymentIntent()` | a second payment for the same intent — the doubled balance |
| `placeOrder()` | re-dispatches order completion, re-sending the receipt |
| `processExpressCheckoutOrder()` | creates and saves a *new* billing profile, orphaning the first |

## Decide it from the order, before asking Stripe

The ordering is not incidental. Whether there is anything left to do is a
question only the order can answer — a succeeded intent says the money was
taken, not whether this site already recorded it. Only an order that has left
`draft` says that.

Asking Stripe first also turns the already-finished case from a no-op into a
failure: the intent the order was matched against is **cleared once it
completes**, so `getStripeIntentFromRequest()` rejects the very intent that
succeeded, as missing or invalid.

## Not the cross-environment double charge

The two look alike in a summary and are nothing alike underneath — check which
one you have before acting, because the fixes point in opposite directions:

- **This.** Two *Drupal payments* sharing one remote intent id, one charge at
  Stripe, no customer billed twice. Fix is in the code path.
- **[[commerce-stripe-webhook-crosses-environments]].** Two *succeeded payments
  at Stripe* seconds apart, the second one bare, a real card charged twice. Fix
  is in which environment holds the endpoint.

The discriminator is Stripe's side: if Stripe shows one charge, it is this one.

## Status

Fixed for us by a local patch
(`patches/commerce-stripe-return-webhook-race.patch` on sisal, against
commerce_stripe 2.2.1) and filed as
[#3590889](https://www.drupal.org/project/commerce_stripe/issues/3590889); the
patch carries a `ReturnAfterWebhookTest` kernel test. Until it lands in a
release it is still live for every other project, so re-check that the patch
still applies on each `commerce_stripe` bump.

See also [[commerce-stripe-express-silent-failures]] for the other express paths
that fail without an error to read.

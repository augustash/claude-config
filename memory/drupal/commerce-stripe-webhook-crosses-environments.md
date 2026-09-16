---
name: commerce-stripe-webhook-crosses-environments
description: A Stripe account's webhook is account-wide, and commerce_stripe matches an event to an order by the order id in its metadata. Environments sharing a sandbox therefore act on each other's payments - and a second environment can charge the card again.
type: reference
---

# A Stripe webhook charges a card in the environment it was never made for

A Stripe webhook endpoint belongs to the **account**, not to a site. Every environment sharing
those keys - local, a multidev, dev - produces events that Stripe delivers to whichever
endpoints that account has. commerce_stripe then matches an event to an order by **the order id
it put in the intent's metadata**:

```php
$payment = $payment_storage->loadByRemoteId($payment_intent->id);
if (!$payment) {
  $order_id = $payment_intent->metadata['order_id'] ?? NULL;
  $order = $order_storage->loadForUpdate($order_id);
  if ($order->getState()->getId() === 'draft') { … }
}
```

Every environment is a database copy, so **order 155188 exists in all of them and is a
different order in each**. The receiving site finds no payment for that intent - it never made
it - looks up its own order of that number, finds a draft, and processes the event against it.

The damage is not just a wrong order marked paid. `handlePaymentIntent()` hands off to
`createPayment()`, which reads the intent id **stored on the order**, not the one the webhook
named. The receiving site's order has none, so it takes the off-session branch, creates a *new*
intent and confirms it against the payment method attached to the event - **charging the card a
second time**. On sisal that presented as one checkout producing two succeeded payments seconds
apart, the second one without the description, breakdown or shipping the site puts on its own
intents, and with a Stripe customer created for the *receiving* site's account holder. The
local site's logs are clean: nothing happened there.

## Recognising it

- Two succeeded payments for one order, seconds apart, only one recorded in Drupal.
- The extra payment carries none of the site's own intent decoration.
- A Stripe customer or email belonging to a person unrelated to the order - the receiving
  site's copy of that order has a different customer.
- Nothing in the paying site's logs, because the second charge happened elsewhere.

## Avoiding it

- **One endpoint per Stripe account, pointed at one environment.** In a sandbox that is
  wherever review happens; live gets its own account or its own endpoint.
- **Keep a live endpoint.** It is what places a paid order when the customer closes the tab
  before the return, and what syncs a refund taken in the dashboard - so the fix is moving it,
  never deleting it.
- **While a review environment holds the endpoint, stop paying locally.** Local checkout sends
  its events there.
- **Check which environments hold live keys** before assuming this is a sandbox-only problem.
  The same mechanism with live keys charges a real card twice.

The upstream half - `createPayment()` trusting the order's stored intent over the one the
webhook named - is also why a single site can double charge if those two ever diverge. See
[[commerce-stripe-intent-survives-gateway-change]] for how an order comes to hold an intent
that is not the one being confirmed.

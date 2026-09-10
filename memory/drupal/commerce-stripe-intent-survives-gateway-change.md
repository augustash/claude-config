---
name: commerce-stripe-intent-survives-gateway-change
description: commerce_stripe discards a stored payment intent when the order's payment_method changes, never when its payment_gateway does. With a Stripe gateway instance per method, switching radios re-uses the previous method's intent and confirms against a method list it is not on.
type: reference
---

# A Stripe intent outlives the method it was made for

Offering each Stripe method as its own checkout radio takes a **gateway instance per method** -
Commerce builds one option per gateway, so a single instance cannot present both a card option
and an Affirm option. Each instance narrows its intent to its own method.

The trap is that the intent is stored on the order and is not reliably discarded when the
customer changes their mind. `OrderPaymentIntentSubscriber::onOrderPreSave()` only cancels it
when `payment_method` changes:

```php
$payment_method = $order->get('payment_method')->getString();
$original_payment_method = $order->original->get('payment_method')->getString();
if ($payment_method !== $original_payment_method) { ... $order->unsetData('stripe_intent'); }
```

Both *new* methods leave `payment_method` empty, so moving between them changes nothing it
watches. The card's intent survives into Affirm, and Affirm renders against
`payment_method_types: ["card"]`. It looks fine - Stripe paints the Affirm UI optimistically -
and fails at confirmation.

It hides easily: switching *from a saved card* does change `payment_method`, so that path
invalidates correctly and the bug never shows. Test new → new.

**Fix:** discard the intent yourself when the gateway changes, wherever you record the
selection:

```php
$current = $order->get('payment_gateway')->target_id;
if ($current && $current !== $gateway->id()) {
  $order->unsetData('stripe_intent');
}
```

**Check it by the client secret, not the UI.** Two picks that yield the same
`clientSecret` are the bug; the rendered element tells you nothing.

## Don't create the intent from a default

Commerce preselects the first payment option, so simply arriving at the step mints an intent
for a method nobody chose - inferred from sort order. Leave the radios unanswered unless a
stored method is on file, and the intent is created when someone actually picks: one intent,
for the method they meant, and none at all for visitors who read the page and leave.

## Related

- [[commerce-stripe-return-step-hardcoded]] - the pane that renders the element also hardcodes
  its return step.
- [[commerce-stripe-affirm-setup-future-usage]] - why an Affirm instance wants
  `payment_method_usage: single_use`.

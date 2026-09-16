---
name: commerce-stripe-return-step-hardcoded
description: Moving commerce_stripe's stripe_review pane off a step literally named `review` makes Stripe take the money while Drupal records nothing - no payment method, no payment entity, no placed order. The pane hardcodes 'review' in its return URL and the return controller validates that against the order's own step.
type: reference
---

# Moving the Stripe Payment Element off the review step

`StripeReview::buildPaneForm()` builds its Stripe return URL with the step hardcoded:

```php
'returnUrl' => Url::fromRoute('commerce_payment.checkout.return', [
  'commerce_order' => $this->order->id(),
  'step' => 'review',
], ['absolute' => TRUE])->toString(),
```

That is safe only while the pane sits on a step of that name. Put the card fields on the
`payment` step - so the customer enters a card where the page says Payment - and the order is
still on `payment` when Stripe sends them back. `PaymentCheckoutController::validateStepId()`
compares the requested step against the order's own **before doing anything else**, and
redirects on a mismatch:

```php
$step_id = $this->checkoutOrderManager->getCheckoutStepId($order);
if ($requested_step_id != $step_id) {
  throw new NeedsRedirectException(...);
}
```

So `onReturn()` never runs. Stripe has charged the card; Drupal has no payment method, no
payment entity and no placed order, and the customer is looking at the payment step again.

**Symptom to recognise:** the payment step reloads with the card form gone or misbehaving, the
order still `draft` with a zero `totalPaid`, and the intent `succeeded` when you retrieve it.
Nothing appears in watchdog, because nothing failed server-side.

**Fix:** subclass the pane and rewrite `returnUrl` with `$this->getStepId()`, then point
`stripe_review`'s class at it through `hook_commerce_checkout_pane_info_alter()`.

## Two things that are *not* the problem

- `placeOrder()` also hardcodes a step - `getNextStepId('payment')` - but that one is benign,
  and is in fact the module assuming the element lives on a step called `payment`. The express
  checkout controller comments as much where it sets `checkout_step` to `review` "to redirect
  to the complete step".
- An element that mounts and immediately hides is usually a **spent intent**, not a broken
  element: Stripe will render against an intent already `succeeded` and then give up. Clear
  `stripe_intent` on the order before re-testing, or you debug a ghost.

## Related

- The pane also disables the submit button until the element reports `ready`, so a failed
  mount strands checkout with no way forward: release it on `loaderror`.
- [[commerce-stripe-intent-survives-gateway-change]] - the other way an intent ends up wrong
  for the method being confirmed.
- [[commerce-stripe-checkout-pane-ids]] - renaming the pane instead breaks other integrations.

---
name: setup_future_usage silently removes Affirm and Klarna from the Payment Element
description: Configuring commerce_stripe for saved cards drops every single-use method from checkout with no error; scoping the parameter to the card method keeps both, but the reuse check reads the top level.
metadata:
  type: reference
---

# setup_future_usage silently removes Affirm and Klarna from the Payment Element

Symptom: Affirm (or Klarna, WeChat Pay, Alipay) is enabled in the Stripe
dashboard, the domain is registered, everything looks right — and the method
simply never appears in the Payment Element. No error, no log line, no failed
request. It is absent from `payment_method_types` on the intent.

## Why

Stripe drops every payment method that **cannot be saved for later** from any
intent carrying a top-level `setup_future_usage`. `commerce_stripe` sends that
whenever the gateway's **Payment method usage** is anything but *Single use*:

```php
elseif ($this->isReusable()) {
  $intent_array['setup_future_usage'] = $this->getPaymentMethodUsage();
}
```

So the gateway setting that gives returning customers a saved card is the same
setting that removes BNPL from checkout. Proven against the API:

```
setup_future_usage=on_session          -> card, amazon_pay
(none)                                 -> card, affirm, amazon_pay
payment_method_options[card][sfu]      -> card, affirm, amazon_pay
```

**Upstream treats this as either/or.** [#3465469] was closed as a duplicate of
[#3392413], whose entire fix is adding the `single_use` option — i.e. turn
saved cards off. Nobody upstream scopes the parameter per method, so there is
no patch to pick up.

## Keeping both

Scoping `setup_future_usage` under `payment_method_options[card]` satisfies the
card and leaves the other methods alone, because Stripe only filters when the
requirement is intent-wide. Two seams, and the second is the one that is easy
to miss:

1. **On the way out** — subscribe to `commerce_stripe.payment_intent.create`
   and move the key. Supported seam, no duplication of `createPaymentIntent()`.
2. **On the way in** — the gateway decides whether to attach the card to its
   Stripe customer by reading `$intent->setup_future_usage` **off the retrieved
   intent** (`attachCustomerToStripePaymentMethod()`). A value living only at
   card scope reads as absent, so cards silently stop saving and you have
   traded the problem rather than fixed it. Override `getIntent()` to hoist it
   back.

Hoisting is safe: nothing in the module writes a retrieved intent back: every
update goes through `PaymentIntent::update($id, [...])` with an explicit
payload, so the value stays local to the request. There is exactly **one**
reader of that property in the whole module, which is what keeps the override
small — but it is not API, so re-check it on each `commerce_stripe` update.

Implemented on sisal (2026-09-09) as `sisal_commerce`'s
`StripePaymentIntentSubscriber` plus a gateway plugin subclassing
`StripePaymentElement`.

## Decide it on repeat purchase, not on stored rows

The trade only matters if customers actually reuse a card. Count repeat
customers rather than stored payment methods — on a gateway swap the old tokens
are the outgoing processor's and die regardless, so they are not evidence for
either side.

Related: [[commerce-stripe-checkout-pane-ids]] for the other place
`commerce_stripe` silently no-ops on a customised checkout.

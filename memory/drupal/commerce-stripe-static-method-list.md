---
name: Narrowing a Stripe intent makes the gateway's static method list load-bearing
description: commerce_stripe's payment_method_types checkboxes duplicate what the Stripe account already knows, and the duplication is harmless only while automatic_payment_methods is left on; the moment an intent names its types explicitly, a mis-ticked method breaks checkout and a method enabled at Stripe never appears.
metadata:
  type: reference
---

# Narrowing a Stripe intent makes the gateway's static method list load-bearing

A Stripe Payment Element gateway carries two lists of payment methods, edited on
two screens, and nothing reconciles them:

- The Stripe account's own enabled methods, in its default payment method
  configuration — what the dashboard's payment-methods screen writes to.
- `payment_method_types` on the Drupal gateway, plus
  `express_checkout.allowed_payment_method_types` for the express element.

Out of the box the duplication rarely bites, because commerce_stripe's intent
uses `automatic_payment_methods` — Stripe decides what to show at render time,
so the Drupal list is close to cosmetic. It stops being cosmetic the moment an
intent names `payment_method_types` explicitly, which is the usual fix for the
Payment Element rendering a whole menu of methods inside one payment radio.
After that the Drupal list *is* the decision, and both directions hurt:

- **Ticked in Drupal, off at Stripe.** Most types are accepted on an explicit
  list regardless of the dashboard, so the method is offered and simply cannot
  be paid with. Some are rejected outright — `paypal` returns *The payment
  method type "paypal" is invalid. Please ensure the provided type is activated
  in your dashboard*, which fails intent creation and takes the payment step
  down for every customer.
- **Enabled at Stripe, unticked in Drupal.** Silently absent, and it reads as
  Stripe not being set up.

Two things are worth knowing about where those checkboxes come from. They are
not commerce_stripe's: `PaymentGatewayBase` generates them from the plugin
annotation, which the plugin has to declare anyway so commerce knows which
payment method bundles it can store. And the annotation is a ceiling, not a
default — `getPaymentMethodTypes()` intersects it with the merchant's
configuration, so a type missing from the annotation can never be enabled, and
silently: the checkbox is simply not on the form. Upstream declares only
`stripe_card`.

**Don't rebuild any of this.** `augustash/commerce_stripe_enhanced` handles it:
the gateway declares all ten method types, the form narrows them to what the
account actually has enabled, and the express/pane overlap de-duplicates itself.
Its README carries the full reasoning, including why a save-time validation was
rejected in favour of deriving the list.

Also useful when reading either list: Apple Pay and Google Pay have no payment
method type plugin, because they are a card presented by a wallet rather than
methods of their own. So narrowing an intent to `card` does not remove them —
they come off through the Payment Element's `wallets` option instead. That
absence is the reliable way to tell a card-riding wallet from a standalone
method, and it follows commerce_stripe rather than a hand-kept list.

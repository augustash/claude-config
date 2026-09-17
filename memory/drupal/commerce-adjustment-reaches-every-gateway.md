---
name: An adjustment reaches every gateway, and they disagree on how to read it
description: A shipment adjustment is copied onto the order, so anything added to mark or label a charge is itemised by PayPal, Affirm and Stripe alike - and they do not agree on what `included` or a `*_promotion` type means, so a marker that reads as inert in the order summary can refuse the order or bill an amount twice.
metadata:
  type: reference
---

# An adjustment reaches every gateway, and they disagree on how to read it

An adjustment is not a label. It is a line in a payload sent to whoever takes
the money, and three things make that easy to forget:

- **A shipment adjustment is not private to the shipment.** commerce_shipping's
  `LateOrderProcessor` copies every one of them onto the order, alongside an
  order-level `shipping` adjustment for the shipment's own amount. So something
  added inside a shipment for one consumer's benefit reaches all of them.
- **`included` is honoured unevenly.** It means "already inside the price this
  decorates", so it must not be added again. commerce core's
  `OrderTotalSummary` skips it, and so does commerce_paypal's `SdkBase`
  (`getAdjustmentsTotal()` and the line-item loop both check `isIncluded()`).
  **commerce_affirm does not check it anywhere** —
  `Redirect::handleAffirmCheckoutAdjustments()` switches on
  `$adjustment->getType()` with no include filter, so an included adjustment is
  charged on top of the amount it is already inside.
- **A positive amount on a `promotion` or `shipping_promotion` type reads as a
  negative discount.** PayPal refuses the order outright; Affirm silently drops
  it from its itemisation; an ERP export that totals by type misses it.

The failure is always the same shape, and it is not subtle: the itemisation
overshoots or undershoots the `total` sent beside it, and the gateway rejects
the order or takes a wrong amount. On one sisal order a $150 surcharge marker
made the itemisation 1300 against a 1150 total.

There is no good place to intercept it. Affirm's `AffirmTransactionDataPreSend`
event fires after the amount is folded into `shipping_amount`, with nothing left
to say which adjustment contributed it, so a subscriber would have to rebuild
the whole payload.

**So: never add an adjustment to mark, label or annotate something.** If the
money is already inside another amount, adding an adjustment for it is a second
charge to at least one consumer. Give the consumer that wanted the label another
way to compute it — a helper on the processor that decided the charge, read
straight from the order — and leave the order carrying only real money.

When a charge genuinely is its own line, give it the type that describes what it
is. A delivery add-on is `shipping`, not `shipping_promotion`: every consumer
that totals shipping then counts it, and it still renders as its own line.

Two things worth checking before trusting any of this on a given site: whether a
`*_promotion` type is carrying a positive amount anywhere, and what each enabled
gateway does with `isIncluded()`. Affirm's omission is upstream and unpatched
here — it was designed around rather than fixed, so it is still live for every
other project.

See also [[commerce-stripe-express-silent-failures]] for the same integration
family failing without an error to read.

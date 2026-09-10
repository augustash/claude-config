---
name: commerce-stripe-empty-express-element
description: "An express/wallet element that measures zero height, or a wallet Stripe reports as unavailable, is usually neither. Measure the container rather than the iframe, and a probe element's availablePaymentMethods does not account for paymentMethods.applePay: 'always'."
type: reference
---

# An empty Stripe express element usually is not broken

The Express Checkout Element renders nothing, or a wallet you expect is missing. Both readings
are usually measurement errors, and both send you hunting a bug that is not there.

## It mounts asynchronously, so an early read returns zero

A poll that gives up before the element paints returns zero, and every conclusion built on that
zero is wrong. **Wait on the container reaching a plausible height, never on a fixed delay**
(see [[no-time-based-test-waits]]).

An earlier version of this note claimed mounts "can exceed 12 seconds". That figure came from a
*probe* element — the very instrument the next section says cannot be trusted — and has not
reproduced since: on the same site, the real element paints in a few seconds. Treat a long
mount as unmeasured rather than expected, and go looking for a cause if one appears.

Measure the **container**, not the iframe:

| container height | meaning |
| --- | --- |
| 0 | not mounted *yet* — keep waiting |
| ~8px | Stripe's hidden controller iframe only |
| ~54px | one wallet (at `buttonHeight: 54`) |
| ~116px | two, stacked |
| ~178px | three, stacked |

`el.querySelector('iframe')` returns the **controller** iframe, which is permanently 8px. Its
height never changes and says nothing about whether buttons painted. Reading it as the signal
produces a confident, stable, entirely false "it rendered nothing".

## A probe element does not measure what the site sends

Mounting your own `expressCheckout` element to ask what is available is a reasonable instinct
and quietly misleading:

- `availablePaymentMethods` reports what Stripe considers *available*. It has no bearing on
  `paymentMethods.applePay: 'always'`, whose entire purpose is to show the button even when
  Apple Pay is unavailable — at the cost of a sign-in flow. A probe omitting that option
  reports `applePay: false` while the real element shows an Apple Pay button, and concluding
  "Apple Pay is domain-gated here" from it is wrong.
- Probe elements frequently render empty even when the site's own element renders correctly,
  so they cannot be used to bisect a rendering problem at all.

Only the site's own element is evidence. If it disagrees with a probe, believe the element.

## Before concluding anything

Check it in an ordinary browser window. Both failure modes above look identical to a real
outage from an automated tab, and the cheapest disproof is a human pair of eyes on the page.

## Related

- Wallets vanishing for a signed-in customer is a different thing entirely:
  [[commerce-stripe-affirm-setup-future-usage]].
- A wallet rendering as a bare gateway-name radio: [[commerce-stripe-checkout-pane-ids]].

---
name: An abandoned offsite payment leaves the order locked, reading as an empty cart
description: A customer who walks away from PayPal or Affirm returns to "your cart is empty" and cannot get back to the payment form - the order is locked at payment_process, which re-redirects on every visit
metadata:
  type: reference
---

# An abandoned offsite payment leaves the order locked

Redirecting to an offsite gateway locks the order so nothing can modify it while
the customer is away. Completing or cancelling clears that. **Walking away does
neither**, and the state it leaves behind is invisible in a way that reads as
data loss:

- `commerce_cart`'s cart provider **excludes locked orders**, so the cart block
  and `/cart` report the cart as empty while the order sits there intact.
- `checkout_step` stays at `payment_process` - the step whose job is to perform
  the redirect. So returning to `/checkout/<id>` does not show the payment form
  again; it resumes the handoff and bounces the customer straight back out to the
  gateway.
- A payment method entity is left behind with **`remote_id` NULL**, and on the
  next visit it is preselected in place of the fresh option.

Seen twice in one session on 2026-09-18 (sisal, PayPal then Affirm), so it is not
gateway-specific - it is what offsite redirect plus a closed tab produces.

## Confirming it rather than guessing

`locked`, `checkout_step` and the payment count together tell the whole story: a
locked order at `payment_process` with **zero** payments is an abandonment, not a
failed charge. Nothing was taken.

## Recovering one

The gateway's own cancel URL is the designed exit and unlocks properly. By hand:
unlock, and put `checkout_step` back to the payment step - otherwise the next
visit redirects again. Delete the remote-less payment method so the fresh option
returns.

## Do not tidy an order while someone is in the flow

Reading is safe; writing races the return. On 2026-09-18 a cleanup ran against an
order whose customer was, at that moment, finishing at PayPal: the capture landed
first, so the "abandoned" order being repaired was actually a placed one, and
clearing its `payment_gateway` and `payment_method` damaged a real record. Worse,
an earlier clear of the gateway mid-flow surfaced to the customer as *"no payment
method selected"* on a form where they had plainly selected one - a phantom bug
that costs real time to chase.

So: while anyone is at the gateway, read only. The order is not stuck in a way
that gets worse by waiting.

## Worth fixing, not just knowing

The customer-facing half is a genuine defect. Cold feet at the gateway is
ordinary behaviour, and the site's answer to it is an empty cart plus a checkout
that will not let go of the redirect. A cancel route that unlocks and steps back,
or a cart that surfaces a locked order as recoverable, is the fix.

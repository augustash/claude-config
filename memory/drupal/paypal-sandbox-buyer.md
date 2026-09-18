---
name: PayPal's sandbox only accepts cards it generated itself
description: A generic test card like 4111 1111 1111 1111 is refused in the PayPal sandbox - pay with the buyer's balance, or with the card PayPal generated for that sandbox account; plus how to swap buyer accounts mid-test
metadata:
  type: reference
---

# PayPal's sandbox only accepts cards it generated itself

`4111 1111 1111 1111` and friends are rejected. PayPal validates against card
numbers **it generated for that specific sandbox account**, unlike Stripe, where
`4242 4242 4242 4242` is universal - so a number carried over from Stripe or
Braintree testing looks like a broken integration and is not one.

Do not add a card at all. A sandbox *personal* account is funded, so pay with the
**PayPal balance** on the funding screen. If you have navigated into "Add a card",
back out rather than filling it in.

If the account has neither balance nor card:
`developer.paypal.com` -> Testing Tools -> Sandbox Accounts -> the personal
account -> its details panel carries a generated card number, expiry and CVV, and
the balance can be topped up on the same screen. Creating a fresh personal
account is usually faster than repairing a broken one; they come funded.

## Swapping buyer accounts mid-test

Sign out at `https://www.sandbox.paypal.com/signout`, then **restart the payment
from the site**. Do not go back to the previous PayPal URL: an approval link is
bound to the PayPal order and session that created it, so after a signout it
errors rather than offering a login. The abandoned PayPal order is harmless.

Restarting from the site means a fresh order, which also means the *site's* order
comes back from its abandoned state - see
[[offsite-gateway-abandonment-lock]], because a half-finished PayPal trip is
exactly what leaves a Drupal order locked and apparently cartless.

## What reaching PayPal already proves

The redirect cannot happen without a successful `v2/checkout/orders` call, so a
sandbox login screen with a real session is proof the client id and secret
resolved - useful when the point of the exercise is credential wiring rather than
the flow. The funding instrument is PayPal's side of the fence; capture is what
still needs a completed payment.

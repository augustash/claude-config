---
name: commerce_stripe's express checkout fails silently in three places
description: Express wallet orders place successfully and record almost nothing - no email, no billing profile, a shipping address with no street, a delivery choice that cannot be read back. Three separate causes, none of which raise an error, all fixed by patches augustash/commerce_stripe_enhanced carries.
metadata:
  type: reference
---

# commerce_stripe's express checkout fails silently in three places

The Express Checkout Element integration is new in commerce_stripe 2.2.x and the
paths below have almost certainly never worked on a current Stripe API version.
Every one of them fails without an error, a log line or a console warning: the
order places, the customer sees a completion page, and the damage is only
visible in the database.

Measured against 2.2.1 with API version 2026-07-29.dahlia.

## Nothing the wallet collected is recorded

`processExpressCheckoutOrder()` reads the charge as `$intent->charges->data[0]`
and returns early if that is unset. **Stripe removed `charges` from the
PaymentIntent object in API version 2022-11-15**, replacing it with a single
`latest_charge`. So on any newer version the method returns four lines in, having
recorded none of: the customer email, the billing profile, or the full shipping
address. The address keeps only the city, state and postcode that the
`shippingaddresschange` event supplies, so **the order arrives with no street to
deliver to** - and any subscriber to the shipping-profile alter event never runs,
because the dispatch is below that return.

Symptom to recognise: a placed express order whose `commerce_order.mail` and
`billing_profile` are NULL while Stripe holds all of it.

## A delivery option's identity is lost

Express shipping options are published to the wallet keyed on the *shipping
method* id, and the customer's choice is applied back with
`setShippingMethodId()`. Two consequences:

- A method offering more than one service - a carrier with Ground beside Next
  Day, or one service with and without a surcharge - sends several options
  sharing one id. The wallet cannot tell them apart and the site cannot read
  back which was picked.
- `setShippingMethodId()` records the method alone, leaving the service, its
  label and the rate's own amount untouched. An order refresh happens to repair
  those, which is why it goes unnoticed.

The rate id (`methodId--serviceId`) is what should be published, applied through
`ShipmentManager::applyRate()`.

## Only one express element works per page

The element's settings hang on one flat `drupalSettings` key, so a page carrying
more than one - a cart page listing several carts - keeps only the last attached
and every other container renders empty at zero height.

## Where each wallet puts the phone number

Not a bug, but it reads as one. `phoneNumberRequired: true` is honoured
differently per wallet, and the element exposes no way to ask for a *shipping*
phone specifically:

| wallet | `charge.shipping.phone` | `charge.billing_details.phone` |
| --- | --- | --- |
| Apple Pay | null | present |
| Google Pay | present | present |
| Amazon Pay | null | present |

So billing details is the only source that covers all three. Note also that
`charge.payment_method` is an **id string** unless expanded - reading
`$charge['payment_method']['billing_details']` finds nothing, silently.

## Don't rebuild any of this

`augustash/commerce_stripe_enhanced` carries a patch for each and the wallet
handling around them; its README has the full reasoning. See
[[commerce-stripe-static-method-list]] for the related trap that narrowing an
intent makes the gateway's static method list load-bearing, and
[[stripe-wallet-testing]] for how to actually test a wallet in sandbox.

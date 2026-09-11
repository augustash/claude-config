---
name: Testing Apple, Google, Amazon Pay and Affirm in Stripe sandbox
description: What each wallet actually requires to complete a sandbox payment - domain registration, a forced display flag, an account created on the spot, a pin printed on the page - and which of Stripe's own testing instructions are wrong for the Express Checkout Element.
metadata:
  type: reference
---

# Testing Apple, Google, Amazon Pay and Affirm in Stripe sandbox

Each wallet blocks in a different place, and Stripe's documented testing steps
are written for the Payment Element - they do not describe what the Express
Checkout Element actually does.

## Register every domain, including the local one

`/v1/payment_method_domains` gates the wallets. Stripe accepts a
**`*.ddev.site` domain in test mode**, so all three wallets can be driven
locally once it is registered; without registration Apple Pay silently never
appears. Register local, multidev and production - a registered domain only acts
on the host actually serving, so there is no cost to leaving them all enabled,
and the launch-day trap of a disabled production domain disappears.

A disabled domain produces no error anywhere. The button is simply absent.

## Apple Pay outside Safari needs `always`

Stripe: *"Apple Pay on non-Safari desktop browsers is only supported when its
property in `paymentMethods` is set to `always`."* So the same setting that stops
`auto` hiding a wallet on the browser that doesn't own it is what lets Apple Pay
be tested in Firefox or Chrome at all. Google Pay likewise.

`always` is documented for Apple and Google only. Amazon Pay stays `auto`, and
`auto` means *"a supported platform **and** when we determine it's advantageous
for your conversion"* - which is why Amazon Pay shows on desktop and not on an
iPhone, with nothing to override it.

## Amazon Pay: create the buyer on the spot

The express button redirects to Amazon's **sandbox** sign-in - hosted on
`www.amazon.com/ap/signin`, the production host, distinguished only by a sandbox
badge. Do not go looking for a credential: click **Create your Amazon Account**
on that page and it provisions a sandbox buyer. Then Amazon's own test cards
drive the outcome (Visa ending 1111 succeeds, Amex ending 0005 declines).

Stripe's Amazon Pay page promises "a test payment page where you can approve or
decline" - that is the Payment Element flow, not the express button.

## Affirm: the pin is printed on the page

The redirect lands on `sandbox.affirm.com`, which asks for a mobile number and
then a pin. **The sandbox banner on that page states the pin** - do not guess it
from a search result; it has been `123456` where third-party guides say `1234`.
Then name, birth date, email, a plan, and Confirm. Turn **AutoPay off** first:
it is enabled by default and makes the bank fields required, which blocks the
confirm with no visible reason.

Affirm is $35-$30,000 USD, enforced at intent creation - see
[[commerce-stripe-express-silent-failures]] for where those limits belong.

## Driving a wallet from automation

The wallet sheets are native UI and cannot be scripted. What *can* be exercised
without a payment are commerce_stripe's own express endpoints - POST to
`/commerce-stripe/express-checkout/shipping-address-change/{order}` and
`/shipping-rate-change/{order}` with the JSON a wallet would send - which proves
the rate list, the delivery capture and anything keyed on the express request.

Two things that waste time in a browser: a synthetic `.click()` is not a trusted
event and payment UIs ignore it (use real input), and Drupal's own checkout form
can be advanced by POSTing the serialised form, which is the only way past an
address field a Places widget keeps clearing.

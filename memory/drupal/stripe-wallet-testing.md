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

**Registrations are per-mode.** A test key lists only the sandbox's domains, so
a domain reading `enabled=False` there says nothing about live — and checking
with the wrong key is an easy way to raise a launch blocker that isn't one. The
same separation applies to enabling a method: activating Affirm or Amazon Pay in
sandbox does not carry to live.

## `always` is documented for non-Safari, but do not predict absence from it

Stripe: *"Apple Pay on non-Safari desktop browsers is only supported when its
property in `paymentMethods` is set to `always`."* Read that as what `always`
guarantees, **not** as what `auto` refuses.

Measured against it on 2026-09-18: **Apple Pay and Google Pay both rendered and
completed payments in Firefox Developer Edition** on macOS with the methods left
at `auto` - the browser that owns neither wallet. So the documented sentence is
not a reliable negative, and quoting it to rule out a browser talks a developer
out of two tests that work. Try the browser; believe the button over the doc.

That matters because `always` is not reachable from config anyway:
commerce_stripe's `ExpressCheckoutButtonsBuilder` emits only `'auto'` (allowed)
or `'never'` (unticked) per method, so setting `always` needs a JS-settings
alter. Worth knowing before promising someone a single-browser test of two
wallets.

Amazon Pay has no `always` documented at all, and `auto` means *"a supported
platform **and** when we determine it's advantageous for your conversion"* -
which is why it shows on desktop and not on an iPhone.

## Amazon Pay: create the buyer on the spot

The express button redirects to Amazon's **sandbox** sign-in - hosted on
`www.amazon.com/ap/signin`, the production host, distinguished only by a sandbox
badge. Do not go looking for a credential: click **Create your Amazon Account**
on that page and it provisions a sandbox buyer. Then Amazon's own test cards
drive the outcome (Visa ending 1111 succeeds, Amex ending 0005 declines).

Stripe's Amazon Pay page promises "a test payment page where you can approve or
decline" - that is the Payment Element flow, not the express button.

## Affirm's sandbox remembers every phone number you have used

The number is the account key, and a number used before comes back as *that*
sandbox user carrying its prior loan state - so a run that worked last month
stalls this month with nothing in the integration at fault. Nothing warns you.
Walk a counter of throwaway numbers and record where you got to; a fresh number
is a fresh applicant.

Clearing the session needs the cookies for `affirm.com` gone (Firefox: padlock ->
Clear cookies and site data). `sandbox.affirm.com/u/logout` is a 404, and the
Sign Out in its header is inside a JS-rendered menu that automation does not
reliably reach.

## Affirm: the pin is printed on the page

The redirect lands on `sandbox.affirm.com`, which asks for a mobile number and
then a pin. **The sandbox banner on that page states the pin** - do not guess it
from a search result; it has been `123456` where third-party guides say `1234`.
Then name, birth date, email, a plan, and Confirm. Turn **AutoPay off** first:
it is enabled by default and makes the bank fields required, which blocks the
confirm with no visible reason.

Affirm is $35-$30,000 USD, enforced at intent creation.

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

## The card element *can* be driven, by plain field names

Unlike the wallet sheets, the Payment Element's card fields are ordinary inputs
in a cross-origin iframe, so a driver that can target a frame fills them
directly. The frame is `iframe[title="Secure payment input frame"]` and the
fields are named, not id'd:

    input[name="number"]  input[name="expiry"]  input[name="cvc"]  input[name="postalCode"]

Two traps. **An accessibility/DOM snapshot of that frame returns only nested
`div`s** — Stripe's inputs never appear in it, so the fields look absent and the
obvious next move is to give up on the iframe; address them by selector without
snapshotting first. And **`postalCode` is easy to miss**: it is Stripe's own
field, separate from the billing address already collected by Drupal, and
leaving it empty blocks submission *with no error text* — the Place Order button
simply does nothing, which reads as a broken button rather than an incomplete
form.

Verified 2026-09-17 on sisal (Firefox via the devtools MCP, `fill_by_uid` with
its `frame` argument). Note the same tool's `evaluate_script` ignored `frame`
and ran against the parent document, so read back state through the driver's
fill/click results rather than by evaluating JS "inside" the frame.

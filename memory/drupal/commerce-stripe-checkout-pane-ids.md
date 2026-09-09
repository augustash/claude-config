---
name: commerce_stripe's checkout integrations key on stock pane ids
description: Rename the payment, contact or shipping checkout panes and three commerce_stripe features stop engaging — no error, they are just absent, and the visible one is a bare gateway-name radio with no card logos.
metadata:
  type: reference
---

# commerce_stripe's checkout integrations key on stock pane ids

`commerce_stripe_form_commerce_checkout_flow_alter()` hangs three separate
features off `isset()` checks for the **stock** checkout pane ids:

| Guarded on | Provides |
| --- | --- |
| `contact_information.email` | `data-stripe="email"` for Stripe.js |
| `shipping_information.shipping_profile` | address attributes for prefill |
| `payment_information.payment_method` | custom display label + card icons |

A custom checkout flow that renames or replaces any of those — common on a
build with its own panes — falls through the guard. Nothing errors. The
features are simply never applied, which is far harder to notice than a
failure.

The visible one is the third: the option renders as a bare radio labelled with
the **gateway name** ("Stripe") and no logos, sitting next to gateways that
have them. That reads as worse than what it replaced, and a processor name is
not what customers scan for when looking to pay by card.

Fix is to repeat the same work against the real pane ids in the site's own
module. Panes land at `$form[$pane_id]` (`CheckoutFlowWithPanesBase::buildForm()`),
so the path is the pane id itself — not a guess.

## The label needs configuring before it renders

`getCheckoutDisplayLabel()` returns an **empty string** unless
`checkout_form_display_label.custom_label` is set on the gateway, and the alter
skips on empty. So wiring the alter alone changes nothing; set the label and
the logo list too.

Worth knowing: the `stripe_card` payment method type ships **`applepay` and
`googlepay`** marks alongside the card brands, so the radio can advertise the
wallets rather than hiding them behind a card label. Each other method type
(`stripe_affirm`, `stripe_amazon_pay`, …) carries its own — but only include
those once the matching standalone gateway is retired, or the same brand
appears twice on one screen.

Related: [[commerce-stripe-affirm-setup-future-usage]] for the other silent
no-op in this module.

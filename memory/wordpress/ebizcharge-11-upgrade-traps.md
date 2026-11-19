---
name: ebizcharge-11-upgrade-traps
description: EBizCharge for WooCommerce 11.x (a rewrite of 5.x) keeps the old settings keys but changes what they mean, and ships markup that fades the checkout under Flatsome
metadata:
  type: reference
---

The 11.0.0 rewrite of the EBizCharge gateway (from 5.4.1; versions now track WooCommerce) kept
the `woocommerce_ebizcharge_settings` keys, so an upgrade looks settings-safe. Two of them are not.
Found on atr (2026-11-17), seven weeks after the upgrade, from customers phoning the client
that they could not type their card or untick "Save Card".

## `saveinfo = no` flipped from "never save" to "always save"

- **5.x:** `saveinfo` is "Allow to Save Card"; `no` meant no checkbox and no saved cards.
- **11.x:** `no` means *force save* (`is_force_save_card_mode()`): every card goes into the
  EBizCharge vault, the Save Card box renders checked **and disabled**, and guests are forced
  to create an account. Declined cards get vaulted as well; a card-testing bot left 43 on one
  account.

A site that had saving switched off is silently saving every card after the upgrade. Set
`saveinfo` to `yes` (opt-in) unless the client actually wants forced saving. Do it through
WordPress (`wp option patch update woocommerce_ebizcharge_settings saveinfo yes`) so Object
Cache Pro sees it.

**Cleaning the vault afterwards.** Saved cards live at EBizCharge, not in WP. WP only keeps a
masked last 4 on the order and a `CustNum` user meta that links the customer. Each vault
profile carries a `Created` timestamp, so a WP-CLI eval can list a customer's cards with
`(new WC_Gateway_EBizCharge())->get_customer_payment_methods($uid)` and delete the ones
created after the deploy. Do **not** call the plugin's `delete_payment_method()` for this: it
takes the customer from `wp_get_current_user()`, which is nobody under CLI. Call
`DeleteCustomerPaymentMethodProfile` on the SoapClient with each user's `CustNum`. The only
way a card gets force-saved is through checkout, so scope the run to customers with orders
since the deploy. Export the list first, because the delete cannot be undone.

## `showSavedMethods` defaults to `yes` in the form but `NULL` at runtime

A key missing from the stored settings is never back-filled, so `show_saved_methods` is false
and the saved-card tab never renders at checkout, whatever the admin form displays. Don't
debug the saved-card UI on a site whose settings predate 11.x without checking this first.

## The checkout renders at half opacity under Flatsome

11.x prints a permanent hidden `<div class="blockUI blockOverlay" style="display:none">`
inside `#cc-form`. Flatsome fades `.woocommerce-checkout-review-order:has(.blockUI)` to 0.5,
and `:has()` matches a hidden element, so the payment fields, Save Card and Place Order all
look disabled for good. The fields still work, so a dev who clicks through sees nothing wrong.

**Fix: drop the fade and restyle the overlay as busy** (atr, 2026-11-17). Even the legitimate
refresh fade reads as *disabled*, and on a slow connection the block lasts long enough for
customers to call it broken. Set `#order_review { opacity: 1 }`, then restyle the blockUI
overlay: `opacity: 1 !important` (so Flatsome's spinner isn't faded too), a light translucent
background, `cursor: progress`, the spinner `position: sticky; top: calc(50vh - 20px)` so a tall
payment box keeps it in view, and an "Updating your order…" label on
`#payment > .blockUI::after`. See atr's `themes/atrix/style.css`.

Narrowing Flatsome's `:has()` rule to skip `#cc-form` also clears the permanent fade, but it
keeps the refresh fade customers read as broken, so it is not worth carrying.

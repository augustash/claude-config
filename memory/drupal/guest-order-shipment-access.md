---
name: A guest cannot view their own shipment, so receipts render half empty
description: On a guest order the shipments field renders nothing while the page around it renders fine, leaving a heading with no content - shipment view access delegates to order access, which checkout grants by session rather than by entity access.
metadata:
  type: reference
---

# A guest cannot view their own shipment, so receipts render half empty

A completion receipt or order summary shows its "Shipping" heading with nothing
under it, or an address block that is simply absent, **only for guest orders**.
The same template with the same view mode renders fully for an authenticated
customer, which sends you hunting a data problem that is not there.

## Why

`ShipmentAccessControlHandler::checkAccess()` delegates a `view` to
`$order->access('view', $account)`. A guest has no ownership of their own order
to establish by entity access - checkout grants them the page through its own
session-based access check instead. So the page renders while every entity
rendered *inside* it comes back empty: the shipment, and the shipping profile
with the address and phone on it.

Granting anonymous a shipment permission is the wrong lever - `manage <bundle>
commerce_shipment` would let any visitor view any shipment.

## What to do instead

Read the values and print them, rather than rendering the entity:
`$shipment->getShippingServiceLabel()`, and the address field's raw value off
the profile. An address the customer typed a moment ago is not
access-controlled information to them.

## The heading that printed anyway

Worth knowing separately, because it is what makes the failure visible:

```twig
{% if order.shipments %}          {# always true - a render array is an array #}
{% set content = order.shipments|render|striptags|trim %}
{% if content %}                  {# the field renders its wrappers either way #}
```

A field renders `<div class="field shipments"><div></div></div>` even with no
viewable content, so `|render|trim` is not empty - strip the tags to test. And
print the **array**, not the rendered string: a string from `|render` has lost
its markup safety and Twig escapes it back into visible tags.

## Related

Express wallet orders hit this and a second thing at once - the delivery name on
several surfaces comes from an order data value only the checkout's own delivery
pane writes, which a wallet skips. See
[[commerce-stripe-express-silent-failures]].

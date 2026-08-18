---
name: Prove code is dead against its consumers, not its stored result
description: Before deleting code that looks dead, the claim to prove is "nothing depends on this" — not "the saved state is identical with and without it." A mutation that never persists can still be load-bearing for consumers later in the same request.
metadata:
  type: feedback
---

Before removing code that looks dead, be precise about what you are proving. The claim is
**"nothing depends on this"**. It is not "the stored result is the same either way" — those come
apart exactly when the code exists to serve something *within the same request*.

A write that never reaches the database can still be load-bearing. Anything reading the same
in-memory object before the request ends sees it, and no amount of comparing saved rows will
show that.

## The case that produced this

On sisal (2026-08), `sisal_commerce`'s `alterProduct()` looked dead: it ran on
`CART_ORDER_ITEM_ADD` and called `setTitle(..., TRUE)` and `setUnitPrice(..., TRUE)` on an order
item that nothing saves afterwards — `Order::postSave()` only saves items whose `order_id` is
empty, and `CartManager::addOrderItem()` sets it and saves *before* dispatching. The evidence
looked strong:

- `overridden_title` was `1` **zero times across 188,549 order items**.
- A live add with and without the subscriber produced byte-identical persisted rows, price
  included.
- `RugOrderEarlyProcessor` already set the same price inside `OrderRefresh`, where it does
  persist.

It was removed, and add-to-cart began throwing `Call to a member function subtract() on null`
on a customer-facing path. `google_tag`'s `CommerceCartSubscriber::onAdd` listens on the **same
event** at a lower priority and does `$order_item->getUnitPrice()->subtract(...)`. Rug order
items are created without a unit price, so `alterProduct` at priority 10 was what put one there
before google_tag read it.

The experiment was sound. Its **scope** was wrong: it measured persistence, and the mutation was
never for persistence. The `overridden_title` evidence genuinely proved the *title* half dead,
and that got generalised to the price half, which sat outside the guard and ran on every add.

## How to apply

- **Enumerate consumers, not artifacts.** For an event subscriber, list the other listeners on
  that event *and their priorities* — anything ordered after you can see your mutation. Drupal:
  `\Drupal::service('event_dispatcher')->getListeners('<event.name>')`.
- **Ask what reads this object before the response is sent**, not just what writes it. Preprocess,
  later subscribers, render arrays, analytics/tag plugins, and mail all qualify.
- **A same-request consumer will not show up in a before/after of the database.** If that is your
  only evidence, you have not tested the claim.
- **Removal is not symmetric with a guard.** Adding a guard to a branch that already crashed is
  provably safe — every request that succeeded took the other branch. Deleting a mutation is not:
  it changes what every successful request saw.
- When a fast, low-risk restore exists, prefer restoring over reasoning your way to a second
  removal. Reach for the tidier fix after the bleeding stops.

See also [[proactive-cleanup]], which covers *offering* the cleanup — this is the bar the
cleanup has to clear before it ships.

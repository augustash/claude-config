---
name: commerce-promotion-compatibility-none
description: A promotion silently stops applying though enabled, dated, unlimited, and its plugins all resolve — check compatibility=none plus an auto-add promotion beating it to the order
type: project
---

**A Commerce promotion with compatibility "Not with any other promotions" (`none`) loses to
any promotion that evaluates before it — and an auto-add BuyXGetY promotion applies to every
qualifying order, so the `none` promo effectively never runs again.**

`PromotionOrderProcessor::process()` only enforces compatibility when at least one loaded
promotion is `none`. Once any earlier promotion has registered an adjustment
(`$applied_any`), every `none` promotion is skipped. Evaluation order is weight, then
whatever `loadAvailable()` returns — not something an admin reasons about while editing the
compatibility radio.

Two traps stack on top:

1. **BuyXGetY with `get_auto_add` applies to every qualifying order** (it adds the free item
   itself), so it *always* wins the `applied_any` race against a `none` promo sharing its
   audience.
2. **Shipment offers (`shipment_percentage_off` etc.) write their adjustment onto the
   shipment entity**, which `collectAdjustments()` on the order can't see during promotion
   processing (transfer to the order happens later, in the shipping late order processor at
   priority -100). So a shipping promotion never registers as "applied" for compatibility
   purposes — `none` on a shipping promo both loses to others and can't block others. It has
   no working semantics. Upstream: drupal.org/project/commerce/issues/2869209.

**Diagnosis pattern that found it:** the promotion's own config all checks out (enabled, no
end date, no usage limit, conditions/offer plugins resolve), yet
`commerce_promotion_usage` + shipment adjustment forensics show a hard stop on a specific
date — which matches the promotion's `changed` timestamp, not a deploy. Reproduce in memory
without saving anything: load a real affected order, clear its adjustments, run
`commerce_promotion.promotion_order_processor->process($order)`, inspect order **and
shipment-entity** adjustments; flip the suspect field and rerun.

**Fix:** compatibility `any` unless exclusivity is genuinely wanted — and if it is, model it
with conditions/weights, never with `none` on a shipment promo.

On kow this was "Free Shipping $300+ - Butcher Shop" (promo 20): edited to `none`
2025-12-15, auto-add "Chicken Gift with $200 Order" (promo 23) beat it on every qualifying
order from Dec 19 on, warehouse manually refunded $40 charges for months while everyone
suspected the D11 upgrade.

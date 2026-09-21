---
name: The order screen and commerce_payment_method.type disagree about wallets
description: "Drupal's order admin correctly shows a Stripe wallet payment as \"Visa ending in 1234 (apple_pay)\", but commerce_payment_method.type reads stripe_card for it, identically to a keyed card. Any query, watcher, dashboard or export grouping by type therefore reports zero wallets forever while the order screens plainly show otherwise."
metadata:
  type: reference
---

# The order screen and `commerce_payment_method.type` disagree about wallets

**Trust the order screen; the column lies.** Drupal surfaces a Stripe wallet payment perfectly
well in the UI — on the order detail page, under Payment → Stripe → details, it renders as
`Visa ending in 1234 (apple_pay)`. Nothing is hidden and no Stripe API lookup is needed to see
which wallet was used.

What is misleading is the **`commerce_payment_method.type` column**, which reads `stripe_card`
for that same Apple Pay payment, exactly as it does for a plain keyed card. There is no
`stripe_apple_pay` / `stripe_google_pay` / `stripe_amazon_pay` type; those values do not exist.
At Stripe the wallet is an *attribute of the card* (`payment_method.card.wallet.type`), so
commerce_stripe keeps one `stripe_card` payment method type and stores the wallet in a field
beside it.

So the failure mode is specifically a **reporting and automation** one. The order admin is
right, the SQL is wrong, and the contradiction between them is the tell.

## Where the wallet actually lives

| table | column |
| --- | --- |
| `commerce_payment_method__stripe_card_wallet_type` | `stripe_card_wallet_type_value` (e.g. `apple_pay`) |
| `commerce_payment_method__stripe_card_type` | card brand (`visa`, `amex`, …) |

That first table is also exactly what the admin UI reads: `Card::buildLabel()` in
`commerce_stripe/src/Plugin/Commerce/PaymentMethodType/Card.php` composes "brand ending in
number" and then appends `(wallet_type)` from that field when it is non-empty. The UI and a
correct query are reading the same source — the `type` column was never in that path.

Siblings of the same shape exist per method: `__stripe_card_number`,
`__stripe_cashapp_buyer_id`, `__stripe_cashapp_cashtag`, `__stripe_klarna_dob`,
`__stripe_link_email`, `__stripe_paypal_country`, `__stripe_paypal_payer_id`.

## The cost, and why the wrong answer is sticky

The false conclusion is **reassuring-shaped**: zero wallet-looking `type` values reads as "no
wallet has fired yet", which points at an express element that is not rendering — a bug that
does not exist. On sisal's Stripe go-live (2026-09-21, cutover 16:12 UTC, replacing
Authorize.net as the primary card gateway), a `GROUP BY pm.type` over 12 live payments returned
only `stripe_card`, and a recurring watcher polling live for `stripe_apple_pay` was nearly
scheduled — it would have reported "no wallets" indefinitely no matter how many landed. One of
those 12 was a real Apple Pay (amex, $424.80, order 158180, `pi_3UICsaQmuTzFwDjN1fbABjMg`) —
visible on its own order screen the entire time, and confirmed at the Stripe dashboard.

Reporting wallet share from `type` is the same bug wearing a reporting hat: it will always say
0%.

## The query

```sql
SELECT COALESCE(w.stripe_card_wallet_type_value,'(plain card)') AS wallet,
       COALESCE(t.stripe_card_type_value,'?') AS brand,
       COUNT(*) AS n, ROUND(SUM(p.amount__number),2) AS total
FROM commerce_payment p
JOIN commerce_payment_method pm ON pm.method_id = p.payment_method
LEFT JOIN commerce_payment_method__stripe_card_wallet_type w ON w.entity_id = pm.method_id
LEFT JOIN commerce_payment_method__stripe_card_type t ON t.entity_id = pm.method_id
WHERE p.payment_gateway = 'stripe' AND p.created > UNIX_TIMESTAMP(CURDATE())
GROUP BY 1,2 ORDER BY n DESC;
```

**The LEFT JOINs are load-bearing.** A plain card has no row in the wallet table at all, so an
inner join silently drops every non-wallet payment and makes wallet share look like 100% — the
opposite error, equally confident.

## Stripe's dashboard sees more than Drupal does

Drupal only writes payments that **completed**. A wallet intent created and then failed or
abandoned exists only at Stripe. So for *is express rendering at all?* the dashboard's intent
list is the better instrument than any Commerce table, because a created-then-failed intent is
still proof the element painted and was used.

Verified 2026-09-21 on sisal live (D11, commerce_stripe Payment Element).

## Related

- [[commerce-stripe-empty-express-element]] warns that an express element *looking* empty
  usually is not broken. This is the mirror case: the element is fine and the **measurement**
  is broken.
- [[stripe-wallet-testing]] for getting a wallet to fire in the first place.
- Amazon Pay arrives as a Stripe method rather than its own gateway — same "wallet rides in on
  Stripe" shape; see the sisal project memory
  `.claude/memory/infrastructure/payment-credentials-in-secrets.md`.

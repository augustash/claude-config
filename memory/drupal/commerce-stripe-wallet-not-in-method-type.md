---
name: A wallet payment's method type still reads stripe_card
description: "commerce_payment_method.type is stripe_card for a genuine Apple Pay, Google Pay, Amazon Pay or Link payment, identically to a keyed card — the wallet lives in the stripe_card_wallet_type field table. Grouping by type therefore reports zero wallets forever, which reads as express checkout not rendering."
metadata:
  type: reference
---

# A wallet payment's method type still reads `stripe_card`

There is no `stripe_apple_pay` / `stripe_google_pay` / `stripe_amazon_pay` payment method
type. Those values do not exist, so a query that looks for them finds nothing no matter how
many wallet payments have landed. At Stripe the wallet is an **attribute of the card**
(`payment_method.card.wallet.type`), not a method type of its own, and commerce_stripe stores
it the same way: `commerce_payment_method.type` is `stripe_card` for a real Apple Pay payment
exactly as it is for a plain keyed card.

The wallet *is* recorded locally — in its own field table:

| table | column |
| --- | --- |
| `commerce_payment_method__stripe_card_wallet_type` | `stripe_card_wallet_type_value` (e.g. `apple_pay`) |
| `commerce_payment_method__stripe_card_type` | card brand (`visa`, `amex`, …) |

Siblings of the same shape exist per method: `__stripe_card_number`,
`__stripe_cashapp_buyer_id`, `__stripe_cashapp_cashtag`, `__stripe_klarna_dob`,
`__stripe_link_email`, `__stripe_paypal_country`, `__stripe_paypal_payer_id`.

## The failure this causes, and why it is dangerous

The wrong conclusion is **reassuring-shaped**: no wallet-looking `type` values means "no wallet
has fired yet", which points at an express element that is not rendering — a bug that does not
exist. On sisal's Stripe go-live (2026-09-21, cutover 16:12 UTC, replacing Authorize.net as
the primary card gateway), a `GROUP BY pm.type` over 12 live payments returned only
`stripe_card`, and a recurring watcher polling live for `stripe_apple_pay` was nearly
scheduled — it would have reported "no wallets" indefinitely. One of those 12 was a real Apple
Pay (amex, $424.80, order 158180, `pi_3UICsaQmuTzFwDjN1fbABjMg`), confirmed at the Stripe
dashboard and then in the wallet field table. Express had been working the whole time.

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

Drupal only writes payments that **completed**. A wallet intent that was created and then
failed or was abandoned exists only at Stripe. So for the question this note exists to answer
badly — *is express rendering at all?* — the dashboard's intent list is the better instrument
than any Commerce table, because a created-then-failed intent is still proof the element
painted and was used.

Verified 2026-09-21 on sisal live (D11, commerce_stripe Payment Element).

## Related

- [[commerce-stripe-empty-express-element]] warns that an express element *looking* empty
  usually is not broken. This is the mirror case: the element is fine and the **measurement**
  is broken.
- [[stripe-wallet-testing]] for getting a wallet to fire in the first place.
- Amazon Pay arrives as a Stripe method rather than its own gateway — same "wallet rides in on
  Stripe" shape; see the sisal project memory
  `.claude/memory/infrastructure/payment-credentials-in-secrets.md`.

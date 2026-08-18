---
name: A stored NULL placeholder WSODs every order page on D11
description: After a D10→D11 deploy, admin order pages 500 on the Activity view — old and new orders alike, all at once. commerce_log serializes TranslatableMarkup into its params blob, so a NULL placeholder written years ago becomes a permanent fatal the moment core's typed Html::escape() lands. Includes the detection SQL, the render-time repair via hook_commerce_log_build_alter(), and why the data's age is not the break's age.
type: reference
---

# A stored NULL placeholder WSODs every order page on D11

**Symptom:** hours after a D11 deploy, `/admin/commerce/orders/<id>` returns a 500 on a large
share of orders. The trace runs through a views field → `InlineTemplate` → `TranslatableMarkup`:

```
TypeError: Drupal\Component\Utility\Html::escape(): Argument #1 ($text)
must be of type string, null given
```

Two properties make it read as something it isn't:

- It hits **old and new orders simultaneously**, so it looks like a data migration or a
  mass corruption event rather than a code change.
- Nothing in the order looks wrong. The failing render is the **Activity** view
  (`commerce_activity`), not the order or its items.

## Why D11 flips it

`Html::escape(string $text)` is typed. On **D10** a NULL placeholder coerced to `''` and the
page rendered fine — indefinitely. On **D11** it is a `TypeError`, so every render fatals.

`FormattableMarkup::placeholderFormat()` escapes **every argument**, including placeholders
that do not appear in the template string. An unused NULL arg is still fatal — so
`t('@card_type', ['@card_type' => 'Visa', '@card_number' => NULL])` dies even though
`@card_number` is never rendered.

## Why it is permanent

`commerce_log` **serializes the whole params array — TranslatableMarkup objects included —
into `commerce_log.params`**. A NULL placeholder is therefore frozen at write time and fatals
on every future render. This is the part that surprises: **`composer update` never repairs it.**
Upstream fixing the code that wrote the NULL stops new rows and does nothing for old ones.

## Do not date the break from the data

The data can be a year old while the outage is a day old. Do not claim "this has been broken
since <first bad row>" — a WSOD on a large share of order pages would have been noticed.

`watchdog` retention is usually far too short to date it. Use the lockfile instead:

```bash
for c in $(git log --format=%H -- composer.lock); do
  printf '%s ' "$(git log -1 --format=%ad --date=short "$c")"
  git show "$c":composer.lock | grep -B2 -A8 '"name": "drupal/core",' \
    | grep -m1 '"version"' | sed 's/[^0-9.]*\([0-9][0-9.a-z-]*\).*/\1/'
done | awk '{if ($2!=last) print; last=$2}'
```

Note the lockfile dates the **dev** crossover; production may cross weeks later, and that
deploy is the real start of the outage.

## Find every affected row

Any log whose params hold a serialized markup object with a NULL argument:

```sql
SELECT template_id, COUNT(*), COUNT(DISTINCT source_entity_id)
FROM commerce_log
WHERE params REGEXP 's:[0-9]+:"[@%:][A-Za-z0-9_]+";N;'
GROUP BY template_id;
```

Expect more than one source. Two seen in the wild:

- **`cart_entity_added`** — custom code creating an order item without a `title`.
  `OrderItemStorage::createFromPurchasableEntity()` sets it; anything hand-rolling
  `->create(['type' => …, 'purchased_entity' => …])` does not, and `label()` is read at
  `CART_ENTITY_ADD` before `OrderRefresh` backfills the title.
- **`payment_failed`** — commerce's own `CreditCard::buildLabel()` before it gained
  `card_number->value ?? ''`. Rows stop on the date you upgraded past that fix. **Not
  something to report upstream** — check the installed source before filing.

## Fix: repair at render, not by migration

Restores every historical row at once, needs no data rewrite, and catches sources you have not
found yet. `LogViewBuilder::viewMultiple()` runs
`alter(['commerce_log_build', 'entity_build'], …)`, so:

```php
function MYMODULE_commerce_log_build_alter(array &$build, LogInterface $log, $view_mode) {
  foreach ($build['#context'] as $key => $value) {
    if ($value instanceof TranslatableMarkup) {
      $build['#context'][$key] = _MYMODULE_repair_markup($value);
    }
  }
}
```

Rebuild with `getUntranslatedString()`, `getArguments()`, `getOptions()`, mapping NULL → `''`.
**Recurse** — commerce nests them (`payment_failed`'s `method` markup carries a
`@card_type` argument that is itself a TranslatableMarkup).

This deliberately reproduces D10 behaviour. Blank is what the site rendered all along, which is
also the argument against backfilling: for labels never captured there is nothing to recover.

Also fix the writer, or new rows keep accruing — and harden any `label()` override that wraps a
field value, since a `label()` returning fatal-on-render markup is a defect on its own.

## The same class, one layer up

Any `t()` / `FormattableMarkup` with an unguarded nullable argument is a D11 fatal that was a
D10 non-event. Optional field values (`->value` on a field empty on some entities) are the
common carrier. Worth a sweep after any D10→D11 upgrade — the placeholder-position grep is
`['\"][@%][A-Za-z0-9_]+['\"] *=> *.*(->value|getData\()`.

See also [[d11-symfony-runtime]], [[exo-d11-image-formatters]] and
[[shs-d11-bundle-cache-tags]] for other D11 upgrade breakage.

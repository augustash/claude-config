---
name: Commerce's required price field blocks every variation save on a catalog-only site
description: "an editor ticks a field on a product variation, presses Save and nothing happens — and the 0.00 placeholder that fixes it publishes \"price\": \"0.000000\" into JSON-LD for the whole catalog"
type: reference
---

# A catalog with no prices cannot save a variation

Commerce declares price as a **required base field**:

```php
$fields['price'] = BaseFieldDefinition::create('commerce_price')
  ->setRequired(TRUE);
```

On a site using `commerce_product` purely as a catalog — no cart, no checkout, prices never
entered — every variation form therefore carries an empty required field. The browser refuses
to submit, and the validation bubble points at Price, which is not the field the editor was
editing.

**What it looks like to the person reporting it:** "I ticked the box, hit Save, and it didn't
save." No error they connect to anything, no redirect, no message. Two people can report it
differently, too: the same flag often exists on the PRODUCT form (which has no price field)
and on the VARIATION form (which does), so whoever edited at product level says it works and
whoever edited a variation says it doesn't. That disagreement is the fingerprint.

## Fill it, don't hide it

Hiding price from the form display also works — `ContentEntityForm` only flags violations for
fields present in the form — but it hides a field they will need the day they sell anything.
Prefer a placeholder:

```php
$variation->setPrice(new Price('0', 'USD'))->save();
```

## ⚠ Then stop the placeholder reaching the structured data

A zero price is still a price to anything reading the entity. On md this made all 184
variations emit:

```json
"offers": { "price": "0.000000", "priceCurrency": "USD" }
```

Invisible on the page, in the JSON-LD graph, saying the inverters are free. Nothing renders
it, no editor sees it, and the first sign is an answer engine repeating it months later.

Any code that decides whether to emit an offer has to treat zero as unpriced, not just NULL:

```php
if ($variant['price'] === NULL || (float) $variant['price']['number'] <= 0) {
  return NULL;
}
```

Check the same for anything else that reads price — a formatter, a feed, a schema builder. The
guard usually exists already and was written against an EMPTY price, which is a different
thing from a zero one.

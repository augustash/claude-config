---
name: Webform drops '#attached' from an element's YAML
description: "a library declared on a webform element never loads — the field renders with its data attributes and nothing listening to them; webform builds elements through its own plugin layer and that key never reaches the render array"
type: reference
---

# `#attached` on a webform element is config that does nothing

Putting a library on an element in the webform's YAML looks right and is silently ignored:

```yaml
model:
  '#type': textfield
  '#attributes':
    data-md-model-pick: 'true'   # arrives in the markup
  '#attached':
    library:
      - md_catalog/model_search  # never loads
```

Webform builds elements through its own plugin layer rather than handing the array straight to
the form builder, so `#attached` does not survive. The field renders, the data attributes are
in the DOM, and the behaviour that was supposed to read them is not on the page — which reads
as a JS bug in the behaviour rather than a missing asset.

## Attach from a form_alter, keyed on the attribute

```php
function mymodule_form_alter(array &$form, FormStateInterface $form_state, $form_id): void {
  if (!str_starts_with($form_id, 'webform_submission_')) {
    return;
  }
  $found = FALSE;
  array_walk_recursive($form, static function ($value, $key) use (&$found): void {
    if ($key === 'data-md-model-pick') {
      $found = TRUE;
    }
  });
  if ($found) {
    $form['#attached']['library'][] = 'mymodule/model_search';
  }
}
```

⚠ **Key it on the element's own attribute, not on a form id.** A second form then adopts the
behaviour by adding the field, which is the point of putting it in config at all — keyed on
form ids, every new form needs a code edit and the one who forgets it gets a field that looks
right and does nothing.

⚠ **Delete the `#attached` once the hook works.** Left in the YAML it implies a second,
working mechanism, and the next reader will trust it.

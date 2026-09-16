---
name: An eXo Alchemist component's Twig variables come only from its declared fields
description: "A key added to $values in ExoComponentHandler::viewAlter() never reaches the component's Twig template. exo_alchemist_theme() builds the theme hook's `variables` from the definition's fields, so anything undeclared is dropped by the theme system — silently, with no error and no warning. To embed a form, declare a field of the built-in `form` type instead of hand-rolling it in a handler."
type: reference
---

# A component's Twig variables come only from its declared fields

Applies to any `exo_alchemist` component in a theme's `components/` directory.

`ExoComponentHandler::viewAlter(array &$values, …)` looks like the natural seam for adding
something extra to a component — a form, a computed list, a block's render array. It is not.
You can write the key, the handler runs, and the template still never sees it.

## The tell

A handler that demonstrably executes — log from inside it and the entry appears — while
`{% if my_key %}` in the component's Twig is never true. No exception, no "undefined variable"
notice, nothing in watchdog. The value simply is not there.

## Cause

`exo_alchemist_theme()` declares the theme hook's variables from the **definition**, not from
what `viewAlter()` produced:

```php
foreach ($definition->getFields() as $field) {
  $theme['variables'][$field->getName()] = NULL;
}
```

plus the modifier/enhancement/animation keys. `ExoComponentManager::view()` then maps every
entry of `$values` onto `$build['#' . $key]`, so the key *is* on the render array — but
Drupal's theme system only passes through variables the hook declared. An undeclared one is
discarded before Twig is reached, and discarding is not an error condition, so nothing is
logged.

The order matters and misleads: the handler runs, the key is set, the render array carries it,
and it is dropped at the very last step.

## Fix

**Declare a field.** Whatever the handler wanted to inject, the definition should name.

For a form there is a built-in field type — do not build this by hand:

```yaml
fields:
  search:
    type: form
    label: Search
    form_class: 'Drupal\your_module\Form\YourForm'
    # form_args: []   # optional, appended to formBuilder->getForm()
```

`ExoComponentField\Form` calls `formBuilder->getForm($form_class, ...$form_args)`, exposes
`{{ search.render }}` plus `search.form.*` and per-element `search.form.field.*`, and — the
part worth not re-implementing — swaps the live form for a placeholder inside Layout Builder,
so the builder UI does not nest a real form in the editing form.

Because `form` extends `ExoComponentFieldComputedBase` it adds **no field storage**, so it
costs nothing in config beyond the definition.

A `form_class` whose `buildForm()` takes required arguments needs them defaultable — YAML can
only carry scalars, so a signature wanting a `Url` object should fall back internally rather
than being passed one.

## Corollary: you rarely need the toggle field you were about to add

Alchemist already gives editors per-instance field hiding (`alchemist_data.hidden`). A
`show_x` boolean beside the thing it reveals duplicates that and is one more field to keep in
sync — let the field itself be hidden instead.

## Evidence it bites people

`kow`'s `components/giftcard_balance/GiftcardBalance.php` is a handler that sets
`$values['balance_form']` and is padded with green/blue/purple `#markup` debug divs — someone
chasing this exact disappearance and instrumenting harder rather than reading
`exo_alchemist_theme()`. Its sibling SCSS also sits at `src/giftcard_balance.scss` instead of
`src/styles/`, so it never compiles. Treat that component as a cautionary artefact, not a
pattern to copy.

See [[exo-component-css-loses-to-region-content]] for the other trap that costs a round of
debugging when building one of these.

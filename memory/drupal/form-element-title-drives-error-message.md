# A required element with no #title announces an empty error

A `#required` form element built without `#title` fails twice, and the second failure
looks nothing like the first:

1. **No accessible name.** Screen readers announce it as bare "edit, required". A
   `#field_suffix` (`ft.`, `in.`, `%`) is rendered outside the label association and does
   not name the field, however obvious it looks on screen.
2. **An empty validation message.** Drupal cannot build the "field is required" string
   without a title, so it raises an error carrying *no text*. The page renders a
   `role="alert"` region containing nothing but Drupal's visually-hidden "Error message"
   heading. A screen reader user hears "Error" and is told nothing else — which field,
   or what to do.

`FormValidator::validateFormElement()` (`web/core/lib/Drupal/Core/Form/FormValidator.php`,
~line 300) is explicit, and its own comment prescribes the fix:

```php
// A #title is not mandatory for form elements, but without it we cannot
// set a form error message. So when a visible title is undesirable, form
// constructors are encouraged to set #title anyway, and then set
// #title_display to 'invisible'. This improves accessibility.
elseif (isset($elements['#title'])) {
  $form_state->setError($elements, $this->t('@name field is required.', ['@name' => $elements['#title']]));
}
else {
  $form_state->setError($elements);   // no message
}
```

**Why:** the second symptom presents as a validation or theming bug — "the error is
blank" — with nothing pointing at a missing label, so it gets chased in the wrong layer.
One omission produces both a WCAG 4.1.2/1.3.1 failure and a WCAG 3.3.1 failure, and one
line closes both.

**How to apply:** give every `#required` element a `#title`, and where the design has no
room for a visible label set `#title_display => 'invisible'` rather than dropping the
title. Make the title self-sufficient — paired fields want "Width in feet" / "Width in
inches", not "Feet" / "Inches", because a fieldset legend is not reliably announced with
each field. Suspect this the moment an alert region renders with an empty `.message`.

Checking a form: an element's accessible name is empty if it has no `label[for]`,
`aria-label`, `aria-labelledby`, or `title` — a placeholder does not count. Related:
[[phunit-testing]] for asserting it, and note that third-party embeds (Klaviyo in
particular) ship their own permanently-empty `role="alert"` nodes, so confirm an empty
alert is Drupal's before chasing it.

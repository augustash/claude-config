---
name: Neo's base.css out-ranks the theme on form buttons
description: "Neo's dist/base.css styles `:is(form, .ui-dialog-buttonset) .button--primary` — specificity (0,2,0), and it loads AFTER the theme's front.css. A theme rule on a submit button at (0,2,0) ties and loses on source order, so only the properties Neo does not set survive. Presents as a rule that half-applied, with no !important and nothing visibly overriding it in the sheet you wrote."
type: reference
---

# Neo's base.css out-ranks the theme on form buttons

A theme rule targeting a Drupal/webform submit button applies *partially*. Background, colour,
padding, font-size and border-radius are ignored; min-height, letter-spacing, text-transform
and `::before` all work. Nothing is `!important`, and the rule is plainly present and matching
in the stylesheet you wrote.

## The cause

`dist/base.css` (Neo, built per theme) contains:

```css
:is(form, .ui-dialog-buttonset) .button--primary {
  background: var(--btn-primary-bg-color, var(--btn-bg-color));
  color: var(--btn-primary-content-color, var(--btn-content-color));
  font-size: var(--btn-font-size);
  border-radius: var(--btn-border-radius);
  /* padding via --btn-px / --btn-py */
}
```

Two things make it win:

1. **`:is()` takes the specificity of its most specific argument.** `:is(form, …)` looks like a
   free element selector, but `.ui-dialog-buttonset` is a class, so the whole `:is()` counts as
   **(0,1,0)**. With `.button--primary` that is **(0,2,0)** — the same weight as an ordinary
   two-class theme selector like `.my-component__form .webform-button--submit`.
2. **`base.css` loads after the theme's `front.css` aggregate.** Equal specificity breaks on
   source order, so Neo wins every tied property.

The half-applied look is the signature: the properties that survive are exactly the ones Neo's
rule does not declare.

## Why it is hard to see

- `.btn` is the obvious suspect and is **innocent**. It sits in `@layer utilities`, and
  unlayered author rules beat layered ones, so `.btn` loses to the theme. Neutralising it
  changes nothing — the real rule is in a different file.
- Enumerating matching rules from `document.styleSheets` misses it if you split
  `selectorText` on commas: `:is(form, .ui-dialog-buttonset) …` splits mid-selector into two
  fragments that both throw in `Element.matches()`, and a `try/catch` that skips silently drops
  the culprit from the list. Test the **whole** `selectorText` — `matches()` handles a comma
  list natively.
- In Tailwind v4, `CSSStyleRule` also exposes `.cssRules` (nested CSS). A walker written as
  `if (r.cssRules) { recurse; continue; }` treats every style rule as a container and scans
  nothing.

## The fix

Out-specify it — (0,3,0) is enough. Anchor on the component root rather than reaching for
`!important`:

```css
/* was: .form-s1__form .webform-button--submit  — (0,2,0), ties and loses */
.form-s1 .form-s1__form .webform-button--submit { … }
```

Give any modifier variant one more class (`.form-s1.form-s1--navy .form-s1__form …`) so it
still out-ranks the base rule it sits beside.

⚠ A bare utility class you intend to reuse (`.dmx-pill-btn`) is **(0,1,0)** and loses to Neo
anywhere it lands on a `.button--primary` inside a `form`. The class is fine for standalone
markup; the weight has to come from the selector that joins the generated button.

## Related

- Webform renders its submit as a `<button>` with a `<span>` label, so `::before` works for a
  leading dot. An `<input type="submit">` is a replaced element and drops `::before` silently.
- Colour choices inside a scheme: [[neo-color-scheme-token-resolution]].

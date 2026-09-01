---
name: A component's CSS silently loses to the theme's .region.content rules
description: "`.region.content` is TWO classes, so an aeon/ash theme rule like `.region.content .exo-form .form-actions .button` scores (0,5,0) — the same as a component rule scoped under a single `.exo-component-x` root, and it wins on source order because the theme's aggregate loads after the component's. The fix is the doubled root selector `.exo-component.exo-component-x`, already the convention in several components; not !important."
type: reference
---

# A component's CSS silently loses to the theme's `.region.content` rules

Bites when styling a form control — a submit button most of all — inside an
`exo_alchemist` component on an aeon-based theme.

## The tell

Your rule is right there in the component's compiled CSS, it matches the element
(`el.matches(selector)` is true), the value is what you wrote, there is no `!important`
anywhere — and the computed style is still the theme's. Everything you check says you should
have won.

## Cause

**`.region.content` is two classes, not one.** That single miscount is the whole memory.

| selector | classes | specificity |
|---|---|---|
| `.region.content .exo-form .form-actions .button` (ash.css) | `.region` `.content` `.exo-form` `.form-actions` `.button` | (0,5,0) |
| `.exo-component-error-page .group--search .exo-form .form-actions .button` | 5 | (0,5,0) |

A tie, so source order decides, and the theme's aggregate loads after the per-component CSS.
Adding one more descendant to your selector keeps pace but never gets ahead, which is what
makes this feel like the cascade is broken.

Worth knowing on aeon/ash specifically: the theme deliberately renders buttons inside
`.region.content .exo-form .form-actions` as **outline** style. Before overriding it, decide
whether the outline is simply the site convention and your component should follow it.

## Fix

Double the root selector so every rule under it gains a class:

```scss
// not .exo-component-error-page
.exo-component.exo-component-error-page {
```

The wrapper carries `class="exo-component exo-component-error-page"`, so this is legitimate
specificity rather than a hack, and it is **already the convention** — in `kow`'s ash theme 9
of ~42 components use the doubled form, all of them ones that had to outrank something. Reach
for it rather than `!important`, which the next person then has to outrank in turn.

## Diagnosing, without wasting the rounds

Walking the CSSOM to find the winner is the right instinct, but a naive pass lies twice:

- Iterating only top-level `sheet.cssRules` **skips anything inside `@media`** — recurse into
  `CSSMediaRule.cssRules` or you will conclude no competing rule exists.
- `style.getPropertyValue()` says nothing about `!important`; you need
  `style.getPropertyPriority()`.

Do both and you will still be staring at two rules that look equal. Count the classes in each
compound selector by hand — that is where the answer is.

Companion trap when building one of these: [[exo-alchemist-theme-variables-from-fields]].

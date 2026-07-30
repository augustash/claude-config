---
name: neo spacing is a token plus an application — use my-component inside a region
description: "`component-spacing` only sets the --spacing-component size token; `py-component` and `my-component` apply it as padding or margin. A component placed inside another component's region wants my-component, because padding cannot collapse against the parent section's own spacing and leaves a visibly bigger gap than its siblings."
type: reference
---

# neo spacing: a size token plus an application

Three classes, and they are not alternatives — two of them pair:

```css
.component-spacing { --spacing-component: calc(var(--spacing) * var(--spacing-base-mult,2)) }
.py-component      { padding-block: var(--spacing-component) }
.my-component      { margin-block:  var(--spacing-component) }
```

`component-spacing` is what the **`spacing` prop** applies — it only sets the size. The
component's own twig decides whether that size lands as padding or margin, by hard-coding
`py-component` or `my-component` on its root.

## Why it matters inside a region

A component nested in another component's region (a `sections_s1` section, a tab, an accordion
panel) sits inside a parent that already carries its own spacing. **Padding cannot collapse**,
so `py-component` stacks the two and the child reads with a visibly bigger gap above it than a
sibling using `my-component`, even though both were given the identical `spacing` value.

The tell: two children of the same region, same `spacing` prop, different gap. Diff their root
classes rather than reaching for the spacing prop — on md, `faqs` had `py-component` while
`table_s1` had `my-component`, and only the padding one looked wrong.

**Default to `my-component` for anything intended to be placed in a region.** Use
`py-component` only when the component paints its own background, where margin would leave the
paint edge-to-edge and the inset has to be inside the box.

## Do not fix it with the spacing prop

Dropping the `spacing` value a step (`md` → `sm`) hides the symptom on one placement and leaves
the inconsistency in the component, so the next placement has it again. It also spends a step
of the design scale on a bug. Change the application, not the size.

No asset rebuild is needed to switch between them — both utilities already exist in the built
CSS as long as *some* component uses each, which is normally true. A `drush cr` is enough.

## First hit

ar-md (md) 2026-07-30. `/support`'s Learn section (`faqs`) sat noticeably lower than
Troubleshooting (`table_s1`) inside the same `sections_s1`. Both had `spacing: md`; only the
application differed. `faqs` → `my-component` fixed it. Note `videos` still uses
`py-component`, so a hub mixing all three needs a deliberate decision about its vertical
rhythm rather than a per-component patch.

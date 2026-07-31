---
name: Neo's component-spacing ramp is bottom-heavy — override the multipliers in the theme
description: "A page whose sections read as run together on mobile while desktop looks right: Neo's default component-spacing is 16/24/56px across base/md/lg, so the gap BETWEEN sections can end up smaller than the gap WITHIN one. There is no settings form — the multipliers are custom properties the theme redeclares."
type: reference
---

# Neo's `component-spacing` ramp is bottom-heavy

`@utility component-spacing` in `neo_alchemist/src/css/_utilities.css` sets three multipliers
against Tailwind's `--spacing` (0.25rem), one per breakpoint tier:

| tier | base | md | lg |
|---|---|---|---|
| `component-spacing` (default) | 4 → **16px** | 6 → **24px** | 14 → **56px** |
| `component-spacing-lg` | 6 → 24px | 14 → 56px | 24 → 96px |

Every tier has roughly this shape — base lands near 30% of lg. Desktop gets room; mobile and
tablet do not.

## The symptom

Sections read as run together on a phone while desktop looks correct, and an eyebrow appears
to belong to the block above it rather than to its own section. Measure it rather than
squinting: **compare the gap BETWEEN two components against the gap WITHIN one** (a component
heading to its own body). On md at 390px that was 16px between and 28px within — separation
smaller than cohesion, which is the rhythm inverted. At 1280px the same page was 56 vs 24.

Nothing is broken; the ramp is simply tuned for desktop. Check it early on any build whose
components carry their own headings.

## The override

There is **no settings form and nothing generates these** — the NeoBuild subscriber only emits
the `*-component` utilities that *consume* `--spacing-component`. The multipliers are written
as `var(--spacing-base-mult, N)` precisely so a site can redeclare them. Put plain rules in the
theme's entry CSS, below the `@import`s:

```css
.component-spacing     { --spacing-base-mult: 8; --spacing-md-mult: 10; }
.component-spacing-lg  { --spacing-base-mult: 10; }
```

Unlayered theme CSS beats Tailwind's utilities layer, so no `!important` and no specificity
games.

⚠ **Retune the neighbouring tier too, or the scale stops being monotonic.** Raising only the
default puts it *above* `component-spacing-lg` at mobile (32px vs 24px) — invisible until
someone picks `lg` from the spacing picker and gets *less* room than the default. Check the
tier above and below whatever you move.

⚠ **Leave `lg` (desktop) alone unless desktop is actually wrong.** The defect is the bottom of
the ramp; changing all three turns a rhythm fix into a redesign.

This is the *size* half of Neo spacing. The other half — whether that size lands as padding or
margin, and why a nested component needs `my-component` — is
[[neo-component-spacing-collapse]]. A gap that is wrong on *one* placement is usually that one,
not this.

## First hit

md 2026-07-31, a Learn article. Confirmed against neo_alchemist 1.0.114 that upstream had not
revisited the ramp, and swept `~/Projects`: **no augustash site overrides these multipliers**,
so expect to be first on any given project.

---
name: neo_color scheme tokens and the :root bake
description: "Neo inverts the primary/base ramps inside a scheme scope, so a component rendered in `.scheme-dark` recolors itself for free — but only if its custom properties are declared INSIDE the scheme. A property declared at `:root` resolves its `var()`s against the root scheme and inherits those fixed colours in unchanged, so the component never sees the inversion. Corollary: ramp references copied from light-scheme rules flip too, and only `--color-*-500` is stable across schemes."
type: reference
---

# neo_color scheme tokens and the :root bake

Two facts that together explain most "this component is unreadable inside a dark scheme" bugs, and one design conclusion about what to do once it renders.

## Neo already inverts the ramps

Inside a `.scheme-dark` wrapper, neo_color re-emits the ramp reversed. Measured on the same page, root vs modal scope:

| token | `:root` | `.scheme-dark` |
|---|---|---|
| `--color-primary-500` | `10 35 67` | `10 35 67` |
| `--color-primary-700` | `6 21 40` (darker) | `177 185 195` (lighter) |
| `--color-primary-900` | `2 7 13` (near-black) | `238 240 242` (near-white) |
| `--color-base-0` | `255 255 255` | `0 0 0` |
| `--color-base-900` | `33 36 40` | `245 246 246` |

So a rule written once as `rgb(var(--color-primary-900))` is near-black on the page and near-white in the modal, automatically. **`--color-*-500` is the anchor and does NOT move** — it is the only stop safe to use when something must stay the brand colour in both. `--color-primary-500-content` (the ink legible on the anchor) is likewise stable.

## The `:root` bake

A custom property resolves its `var()`s **against the element it is declared on**, then inherits the resulting fixed value. A gradient or colour token declared at `:root` therefore bakes the root scheme's colours and inherits them into `.scheme-dark` completely unchanged — the inversion above never reaches it.

The tell is that the token computes **identically** at `:root` and at the element inside the scheme:

```js
getComputedStyle(document.documentElement).getPropertyValue('--my-band')
getComputedStyle(elInsideScheme).getPropertyValue('--my-band')   // same string = baked
```

Fix: declare it on an element inside the scheme (`.scheme-dark .my-component { --my-band: … }`), not at `:root`. Keep the `:root` copy for the default scheme; the nearer ancestor wins by inheritance.

This is the same trap whether the property holds one colour or a whole `linear-gradient()`. It bit twice on md — once on `--ink`/`--heading-ink` (see below), then again on a component's band gradient after the first fix was already documented three files away.

## Corollary: don't copy light-scheme rules verbatim

A component that models both grounds (a `--dark` and a `--light` variant) is tempting to reuse: in a dark scheme, its dark-ground variant should render as its light-ground variant. Restating those rules is right, but their **ramp references cannot be copied literally** — they were authored for the root scheme and flip. A `--light` variant using `rgb(var(--color-primary-950))` for body copy means "very dark navy" on the page and resolves to near-white inside the scheme, on a near-white box. Anything that must stay the brand colour reads `--color-primary-500`.

## Splitting a dual-purpose brand alias

A brand alias like `--navy` that is both the ink of titles and the paint of navy grounds cannot be moved for a dark context without repainting every surface. Split the text job into its own alias (`--heading-ink`, same value, different job); grounds keep reading `--navy`. Then a scheme moves ink without touching surfaces. Convert per component as each one actually enters a dark context rather than in one sweep — each change stays verifiable. Hover states, icons, and text on an explicitly-white plate are legitimate holdouts.

## Design note — invert, don't lift

Once the mechanism works, there is still a choice about *how far* a panel travels. Riding the ramp all the way inverts a dark card to a near-white one, which breaks the scheme's contrast-picked white ink sitting on it. The temptation is to stop partway — but on a two-colour brand (navy + an accent, no light blue), every stop between navy and white is an invented slate the brand does not own, and it looks it.

Prefer crossing all the way to the ground the brand actually has, and inverting the panel's ink with it, over a partial lift. If the ink cannot follow, that is the signal the panel needs its own scheme scope rather than a hand-tuned mix.

First hit: ar-md (md) 2026-07-27, knowledge articles opening in a full-screen `scheme-dark` modal. See [[neo-skills-sync]] and [[neo-alchemist-nested-markup]] for the other neo gotchas.

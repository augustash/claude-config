---
name: Use scale classes, not arbitrary Tailwind values
description: "Arbitrary-value utilities (`sm:text-[2rem]`, `p-[13px]`, `w-[347px]`) are treated as wrong by default on neo projects — Cyle's rule. They opt out of the design scale, so they don't move when the scale is retuned and they read as one-off custom CSS wearing a utility's clothes. Snap to the nearest real class; a 1–2px difference is not worth the exception."
type: feedback
---

# Use scale classes, not arbitrary Tailwind values

**Cyle's guidance** (jacerider/neo maintainer), so it applies across every neo project, not just the one it came up on.

Bracket utilities — `sm:text-[2rem]`, `p-[13px]`, `max-w-[347px]` — are "generally always wrong and custom." Prefer the real class.

**Why:** the whole point of the scale is that retuning it moves everything at once. An arbitrary value silently opts that element out, so it drifts the moment the scale changes, and it hides bespoke CSS inside something that looks systematic. One instance is harmless; the habit is what erodes the system.

**How to apply:** when you find one, resolve the intended value, list what the scale actually offers, and snap to the nearest step:

```
2rem = 32px   →  text-3xl (1.875rem / 30px)   ← nearest
                 text-4xl (2.25rem  / 36px)
```

Take the 2px. A near-miss on the scale beats an exact hit off it. Read the scale from the built CSS rather than assuming Tailwind defaults — neo themes redefine `--text-*`.

Genuine exceptions exist (a value pinned by an external constraint — a third-party embed's fixed dimensions, a sprite offset). Those want a comment saying what pins them, so the next reader doesn't "fix" it.

Worth a sweep when touching a theme's components, since they cluster:

```sh
grep -roE "(sm:|md:|lg:|xl:)?[a-z-]+-\[[^]]+\]" components/*/*.twig | sort | uniq -c | sort -rn
```

Related: [[follow-site-conventions]] — same instinct, applied to a utility scale. Surfaced on ar-md 2026-07-27; two instances theme-wide, both `sm:text-[2rem]`.

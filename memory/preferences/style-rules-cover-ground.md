---
name: Style rules should cover as much ground as possible — page-specific styles break uniformity
description: "When a styling defect shows up on one page, fix it at the widest level that is actually true — the token, the component, the utility — not with a rule scoped to that page or that instance. Offering a per-page fix as the safe option is the wrong instinct; scoping it narrowly is what breaks the design system."
type: feedback
---

# Style rules should cover as much ground as possible

**Kaza, md 2026-07-31:** *"We generally will always want our style rules to cover as much
ground as possible. Rarely ever will we make specific styles for a specific page. It breaks the
whole concept of styling/uniformity."*

**Why:** these builds are design systems, not collections of pages. A defect noticed on one
page is almost always the system's, and the page is just where it was spotted first. Scoping
the fix to that page leaves the defect everywhere else, and now the site has two rhythms
instead of one — the exact thing the component set exists to prevent.

**How to apply:** when a styling defect surfaces, find the widest level at which the fix is
*actually true* and fix it there — a design token, the component's own CSS, a utility — rather
than the narrowest level that makes the symptom go away. Two habits that follow:

- **Don't offer "scoped to this page" as the cautious option.** It reads as risk-management and
  is really deferred inconsistency. Frame the choice as *how wide is this true*, and if the
  answer is "everywhere", say so and take the blast radius seriously instead of dodging it.
- **Do still surface the blast radius before a global change**, with what moved and where to
  look. Wide is the default, not a licence to skip showing the damage — screenshot the other
  pages the token touches. Uniformity is the goal; unreviewed sweeping changes are not.

The corollary is that a genuinely instance-specific need is a signal about the *component*: it
usually wants an additive optional prop, not a bespoke rule. See the reuse → extend → build-new
escalation in the `content-to-components` skill.

Related: [[tailwind-no-arbitrary-values]] is the same instinct one level down — an arbitrary
value opts a single element out of the scale the way a page-scoped rule opts a single page out
of the system.

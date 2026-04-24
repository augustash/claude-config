---
name: Comment style — concise, skip the obvious
description: Comment length is flexible — one line when that's enough, multi-line when the WHY needs it. The real rule is: if the code is obvious, don't comment it.
type: feedback
---

Keep comments concise. Length is flexible — one line when that covers it, multi-line when the WHY genuinely needs more room. The real rule is: **if the code is obvious, don't add a comment.**

**Why:** Good code is self-explanatory at the WHAT level — named identifiers already say what's happening. Comments are for the WHY that isn't visible: hidden constraints, non-obvious tradeoffs, domain quirks, signals from external systems. A comment that restates the code adds noise and rots the moment the code changes. A comment that explains *why* pays for itself on every future read.

**How to apply:**
- Skip comments that restate WHAT the code does — well-named identifiers carry that.
- Skip task-context ("fixes bug X", "added for flow Y") — belongs in the commit/PR.
- Comment when the WHY is non-obvious: hidden constraints, invariants, workarounds, domain quirks, external-system signatures.
- Match length to the explanation. One line is fine when one line is enough. Multi-line is fine when the reasoning needs it. Don't pad to look thorough; don't truncate to look terse.
- Every line should earn its place. If a line adds no new information, cut it.
- Applies to all comment forms (`//`, `/* */`, docblocks) across any language.

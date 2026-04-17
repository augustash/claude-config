---
name: Comment style — efficient, not artificially brief
description: Override default "one short line max" — multi-line comments are fine when the WHY is non-obvious, as long as every line earns its place
type: feedback
---

Default guidance says one-line comments only. User pushed back: that rule is too restrictive. Multi-line comments are welcome when they explain non-obvious reasoning, cross-system context, or domain quirks — but keep them efficient (no filler, no restating what the code says).

**Why:** User values good code over minimal code. A docblock that explains why a block list contains specific substrings, or why a priority ordering matters, pays for itself on every future read. Cutting it to one line loses the "why" and forces future readers to re-derive the reasoning.

**How to apply:**
- Still skip comments that restate WHAT the code does (well-named identifiers carry that).
- Still skip task-context ("fixes bug X", "added for flow Y") — belongs in commit/PR.
- Multi-line is fine when explaining WHY — hidden constraints, invariants, non-obvious tradeoffs, signatures of external systems (crawler patterns, API quirks).
- Every line should earn its place. If a line adds no new information, cut it.
- Applies to all code comments (`//`, `/* */`, docblocks) across any language.

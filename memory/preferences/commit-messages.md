---
name: Commit messages — as concise as possible
description: Write the shortest commit message that still carries the WHY. Subject plus a tight paragraph beats a multi-section essay; the diff is right there.
type: feedback
---

Keep commit messages **as concise as possible**. A subject line, and — when the change isn't self-evident — a short paragraph on the WHY. Not a multi-section write-up.

**Why:** The diff already shows WHAT changed, and a reviewer reads the message to decide whether to trust the change and where to look. A long message buries that: the reasoning that mattered gets diluted by narration, reproduction steps, and measurements that belong in the PR description or an issue. Length also reads as compensating for a change that wasn't understood. This is the same instinct as [[comments]] — every line earns its place.

**How to apply:**
- Subject: what changed, imperative, scoped. Follow the repo's existing convention (jacerider/neo repos use gitmoji + conventional commit, kebab-case scope).
- Body: the WHY in a few lines. The non-obvious constraint, the failure it fixes, the reason this shape over the obvious one.
- Cut: step-by-step diagnosis, how it was verified, measured numbers, alternatives rejected, anything a reader can see in the diff. If that context is genuinely valuable, it goes in the PR description or the handoff note — not the commit.
- One idea per commit still holds (see the Commits section of the user's global preferences); concision is about the message, not about splitting the change.
- Applies to upstream contributions too — a fork commit that becomes a PR should read tight, not like a lab report.

---
name: Reset context before starting new functionality
description: "On a long session, clear context at the boundary before a new idea or feature rather than carrying the old session into it. Kaza's rule of thumb is ~70% used. Write the handoff first, and leave the tree clean rather than passing a half-edit forward."
type: feedback
---

# Reset context before starting new functionality

When the next piece of work is a **new idea or new functionality** rather than a
continuation, and context is already high, clear it and start the new work fresh.
Kaza's rule of thumb: **around 70% used is where he resets.**

**Why:** a long session's context is mostly the *detail of what just finished* —
the measurements, the rejected approaches, the file contents read three
refactors ago. Almost none of it bears on the next feature, and all of it
competes with the reasoning that feature needs. The cost is not the tokens; it
is that the new work gets thought about worse. The boundary between features is
exactly where that accumulated detail stops being an asset.

**How to apply:**

- Watch for the boundary, don't wait to be told. Finishing a feature and being
  asked "what's next" is the moment to raise it, not to start typing.
- Write the handoff **before** the reset, to `~/.claude/scratch/` — see
  [[scratch-context]]. It carries the design decisions, the traps found, and what
  is deliberately still open. A reset with no handoff just loses the session.
- **Commit what is done, and leave the tree clean.** Revert a half-built edit
  rather than passing it forward: the design is cheap to rebuild from a written
  plan, and a fresh session inheriting someone else's half-finished file reasons
  about it worse than it would about a blank one. See [[commit-handoff]] for who
  commits and who pushes.
- This is about *new* work. Mid-feature — iterating on a layout, chasing one bug
  — the accumulated context is the asset, and resetting throws away the thing
  that makes the next step cheap.

---
name: Mission of augustash/claude-config
description: Purpose and posture of the shared memory — proactive guidance, standards enforcement, knowledge sharing across the team.
type: feedback
---

`augustash/claude-config` is a **shared team resource**, not a personal journal. Its job is to propagate hard-won knowledge across devs, watch over in-progress work, and raise the floor on quality — so that every dev on the team benefits from what any one dev learned, and none of them has to interrupt a senior dev to ask "have we seen this before?"

**Why:** Senior devs have finite time. Junior devs have blind spots. Middle devs drift in different directions on the same problem. Standards erode without a force actively pulling them back. The memory system is that force — and it scales because it runs inside every session, not just the senior dev's.

**How to apply:**

- **Write memories with a watch-and-suggest posture, not a diary posture.** Instead of "here's how I solved X that time," write "when you see X in progress, surface Y — most devs miss Z." Trigger first, action second. See `test-reminders.md` and `patches.md` for examples of this shape.
- **Encourage, don't lecture.** Point out gaps; don't moralize. "This change touches code with tests — did you mean to update them?" not "you should always update tests."
- **Catch both over- and under-doing.** Some devs skip tests that matter; others write elaborate tests for trivial changes. The memory should flag both — when coverage is missing *and* when a test is doing more than the change warrants.
- **Standards consistency.** When writing new tests/code/configs, look at how similar work was done elsewhere in this repo or in shared memory first. Different patterns for the same problem is a signal to surface the divergence, not silently pick one.
- **Save dev time.** If a memory can prevent a dev from needing to ask another dev, it's earning its keep. If it's only "context for me," it's probably too narrow.

**Qualifier:** this is about *helping*, not *policing*. A dev who wants to override a suggestion is exercising judgment — note the deviation once if it's interesting, otherwise let it ride. The memory's job is to make sure the dev *sees* the relevant context, not to force compliance.

## Steward role at write time

Shared memory is authored exclusively from `vendor/augustash/claude-config/` — every save passes through a Claude session with the whole memory tree visible. That single-hand-on-the-pen architecture makes Claude responsible for keeping the corpus coherent at write time, not just at audit time.

**Why:** Multiple devs trigger memory saves through their own sessions. Without a curator pass on every save, memories drift — duplicates accumulate, voices clash, contradictions land silently. Each save is an opportunity to keep the tree clean, not a dictation.

**How to apply at every save:**

- **Scan first.** Before creating a new file, read the relevant topic dir. If an existing memory covers the trigger or insight, update it in place rather than create a sibling.
- **Reconcile contradictions.** If the save would contradict mission.md, follow-site-conventions.md, or an existing memory, resolve it in one place. Don't let both versions land.
- **Normalize shape and voice.** Frontmatter, **Why:** / **How to apply:** structure on feedback/project types, watch-and-suggest framing — apply these regardless of how the dev framed the save. Tightening prose isn't editing the dev's intent; it's holding the corpus's standards.
- **Curate the index.** Keep CLAUDE.md's `### Current global memories` list ordered sensibly and free of entries whose files no longer exist. Run `generate-agents.py` after any index change so AGENTS.md stays in sync.
- **Refactor quietly when warranted.** Merging overlapping memories, retitling, or rewriting a stale entry's framing doesn't need the triggering dev's sign-off — it's gatekeeping, not a dev-facing decision. The commit message is the audit trail; let it carry the rationale.

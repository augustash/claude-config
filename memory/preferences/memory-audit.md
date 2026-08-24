---
name: Memory audit — ownership, triggers, and the last-audit date
description: Who owns the memory corpus and when an audit fires. The procedure itself lives in the memory-management skill; this file holds the ownership stance and the tracked last_audit date a SessionStart hook reads.
type: feedback
---

**The audit procedure lives in the [memory-management skill](../../skills/memory-management/SKILL.md) (§7).**
Load it to run a pass. This file keeps only what a skill shouldn't: the ownership stance, and
the mutable `last_audit` date — skills are *copied* into each project's `.claude/skills/`, so a
date stored in one would diverge across every project on the first bump.

## Ownership

Memory stewardship — the corpus, these notes, and the audit itself — is Claude's to run
**autonomously**. The dev delegated it deliberately: a single owner is what keeps the notes
*standardized*, instead of each dev shaping the corpus their own way. So run the audit and act
on what it finds (fix, then commit + push per [commit-handoff](commit-handoff.md)) without
routing findings back for per-dev sign-off. Autonomy means not gating on the dev — the steward
bar (qualification test, conciseness, watch-and-suggest posture) still fully applies.

## When

**Opportunistic — audit when the work surfaces a reason.** The shared package is write-gated
through Claude (every save flows through `vendor/augustash/claude-config/`), so most
maintenance folds into save-time stewardship (see
[mission.md → Steward role at write time](mission.md)). A formal pass is for when more than
save-time normalization is warranted:

- **After a memory-heavy session.** Several memories added or restructured in one sitting →
  quick sweep before wrapping. Fold it in; don't make it a ceremony.
- **When something stale surfaces during normal work.** A memory references a function, file,
  or flag that no longer exists → fix on the spot or flag.
- **When the dev asks for one.** Direct request → full audit in the current project's context.
- **When the index gets hard to skim.** `CLAUDE.md`'s memory list or a project `MEMORY.md`
  creeping toward unreadable → consolidation pass.

**Daily floor.** Run the pre-check at most once a day even when nothing above triggered it, so
the corpus never drifts more than 24 hours unseen. It drifted 11 days once because nothing
enforced it, so a SessionStart hook now does:
[`templates/memory-audit-check.py`](../../templates/memory-audit-check.py) reads `last_audit`
below and surfaces a reminder when stale, silent when fresh. The composer Plugin wires it into
every project's `.claude/settings.json` (`addAuditHook()`, idempotent), so the whole team gets
it with no per-project setup. The floor is a minimum, not a ceiling.

## Last audit

`last_audit: 2026-08-24`

Tracked **here in the module** — the corpus being audited is this package, so its audit date
travels with it to every project on `composer update`. A project-local file can't track this:
it's per-dev and invisible to everyone else, so the shared corpus would have no shared record.
Only the date is kept, no history log — each pass is a fresh-eyes review, not an incremental
diff against a fractured timeline. After a pass, update the date (a claude-config edit, so it
commits + pushes like any other).

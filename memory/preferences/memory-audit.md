---
name: Memory audit — opportunistic with a daily floor
description: When and how to audit shared (augustash/claude-config) and per-project memories. Driven by signals from the work; a daily pre-check is the safety floor so nothing rots more than 24h.
type: feedback
---

## When

**Opportunistic — audit when the work surfaces a reason.** The shared package is write-gated through Claude (every save flows through `vendor/augustash/claude-config/`), so most of the maintenance work folds naturally into save-time stewardship (see [mission.md → Steward role at write time](mission.md)). A formal audit pass is for moments when more than save-time normalization is warranted:

- **After a memory-heavy session.** Several memories added, updated, or restructured in one sitting → quick sweep before wrapping. Don't make it a separate ceremony; fold it in.
- **When something stale surfaces during normal work.** A memory references a function/file/flag that no longer exists → fix on the spot or flag.
- **When the dev asks for one.** Direct request → full audit in the current project's context.
- **When the index gets hard to skim.** `CLAUDE.md`'s memory list or a `MEMORY.md` is creeping toward unreadable → consolidation pass.

**Daily floor.** As a safety net, run the pre-check at most once a day even when nothing above triggered it — so the corpus never drifts more than 24 hours without a glance. Under heavy team use this often catches a pile-up; on quiet days the pre-check no-ops in milliseconds. The floor is a minimum, not a ceiling — opportunistic audits run whenever the signals fire, regardless of the floor's clock.

**The floor is enforced by a SessionStart hook** (it drifted 11 days once because nothing enforced it). [`templates/memory-audit-check.py`](../../templates/memory-audit-check.py) reads `last_audit` below and, on session start, surfaces a reminder via SessionStart `additionalContext` when it's more than a day stale — silent when fresh. The hook is auto-wired into every project's `.claude/settings.json` by the package's composer Plugin (`addAuditHook()`, idempotent, points at the packaged script via `$CLAUDE_PROJECT_DIR`), so the whole team gets it on `composer require`/`update` with no per-project setup. When the reminder fires, do the pre-check and either bump the date or run a pass — folded into the session, not a separate ceremony.

## Last audit

`last_audit: 2026-07-01`

Tracked **here in the module** — the corpus being audited is this package, so its audit date lives with it (committed, travels to every project on `composer update`). A project-local file can't track this: it's per-dev and invisible to everyone else, so the shared corpus would have no shared record. Only the date is kept — no history log. Each pass is a fresh-eyes review, not an incremental diff against a fractured timeline.

After completing an audit, update the date above (it's a claude-config edit, so it commits + pushes like any other).

## Pre-check

Before doing any review work, check whether anything has actually changed since `last_audit`:

- `git -C vendor/augustash/claude-config log --since=<last_audit>`

If nothing has changed, skip the review, bump `last_audit` to today, and move on. The cost of a daily cadence is the pre-check — keep it cheap. (Per-project `.claude/memory/` is reviewed opportunistically in its own project's context, not tracked centrally.)

## What to audit

**Shared memories (authored in `augustash/claude-config`, shipped to projects as `vendor/augustash/claude-config/memory/`):**
- Are referenced files, functions, or modules still accurate?
- Are any memories now obvious from the codebase and no longer worth keeping?
- Are memories concise, or have they grown bloated?
- Can any be consolidated?
- Do any conflict with [mission.md](mission.md) or [follow-site-conventions.md](follow-site-conventions.md)? (i.e. diary-shape rather than watch-and-suggest)

**Per-project memories (`.claude/memory/` in the current project):**
- Same staleness and conciseness checks.
- Does any project-specific knowledge show up across multiple projects and deserve promotion to shared? (Promotion criteria is "useful in ≥2 projects" per [patches.md](../drupal/patches.md) — same rule.) Promotion means authoring it in the `augustash/claude-config` repo, not editing the local `vendor/` copy.

## Self-refinement

If the audit pattern itself needs adjustment — wrong triggers, too noisy, missing something — update this file. The process should evolve based on what actually catches issues.

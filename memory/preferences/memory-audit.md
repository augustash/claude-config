---
name: Memory audit — event-driven, not scheduled
description: When and how to audit shared (augustash/claude-config) and per-project memories. Triggered by natural moments in the work, not by a fixed cadence.
type: feedback
---

## When

**Audit when the work prompts it, not on a schedule.** Calendar-driven audits become either rote or skipped — the dev has already said they don't want a strict timeline. Trigger off real moments instead:

- **After a memory-heavy session.** When several memories have been added, updated, or restructured in one sitting (e.g., a new topic area got built out), do a quick sweep at the end to make sure nothing duplicates or contradicts existing notes. *Don't make this a separate ceremony — fold it into the session.*
- **When something stale surfaces during normal work.** If you reach for a memory and it references a function/file/flag that no longer exists, fix it on the spot or flag it. No formal audit required for one-off fixes.
- **When the dev asks for one.** Direct request → run a full audit in the current project's context.
- **When the index gets hard to skim.** If `CLAUDE.md` or `MEMORY.md` is creeping toward unreadable, suggest a consolidation pass.

## Pre-check

Before doing any review work, check whether anything has actually changed. Use `git log --since=<last_audit>` on the `augustash/claude-config` checkout used for authoring (or on `vendor/augustash/claude-config/` in the current project) and the current project's `.claude/memory/` (settings holds `last_audit`). If neither has changed, skip the review, update `last_audit`, and move on.

## Settings

`~/.claude/claude-config-audit.json` (per-dev, lives outside any project so it survives composer updates). Create on first use:

```json
{
  "audit": {
    "participate_in_review": true,
    "last_audit": "2026-04-22"
  }
}
```

- `participate_in_review` — if true, present proposed changes for approval before applying. If false, apply cleanup silently and summarize.
- `last_audit` — updated after each audit completes (lets the next event-driven audit know what's changed since).

On first audit, ask the dev their preference and save it. Don't ask again unless they bring it up.

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

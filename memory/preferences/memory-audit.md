---
name: Weekly memory audit process
description: How and when to run the active memory audit — Friday sessions, per-dev settings, what to review
type: feedback
---

## When

Weekly, on Fridays. At the start of the first session on a Friday, check `~/claude-config/.settings.json` for the `last_audit` date. If it's been 7+ days (or never run), offer to run the audit before proceeding with the dev's request.

## Settings

`~/claude-config/.settings.json` (gitignored, per-dev). Create it on first use if it doesn't exist.

```json
{
  "audit": {
    "participate_in_review": true,
    "last_audit": "2026-03-28"
  }
}
```

- `participate_in_review` — if true, present proposed changes for approval before applying. If false, apply cleanup silently and summarize what changed.
- `last_audit` — updated after each audit completes.

On first audit, ask the dev their preference and save it. Don't ask again unless they bring it up.

## What to audit

**Global memories (`~/claude-config/memory/`):**
- Are referenced files, functions, or modules still accurate?
- Are any memories now obvious from the codebase and no longer worth keeping?
- Are memories concise, or have they grown bloated?
- Can any be consolidated?

**Per-project memories (`.claude/memory/` in the current project):**
- Same staleness and conciseness checks as global.
- Does any project-specific knowledge show up across multiple projects and deserve promotion to global?

**Personal projects:** If `.claude/.personal` exists in a project, it is a personal project. Still apply staleness and conciseness checks, but never promote its memories to global.

## How

**Pre-check:** Before doing any review, check whether anything has actually changed. Use `git log --since` on both `~/claude-config/` and the current project's `.claude/memory/` to see if memory files were modified since `last_audit`. If nothing changed in either location, skip the audit, update `last_audit`, and move on. Don't waste the dev's time reviewing unchanged files.

Run the audit in the context of whatever project the session started in. This means per-project review covers the current project only — over time, different projects get audited as devs open Friday sessions in different repos.

After completing the audit, update `last_audit` in settings.json.

## Self-refinement

If the audit process itself needs adjustment — too noisy, missing things, wrong cadence — update this file. The process should improve over time based on what's actually useful.

---
name: memory-management
description: >-
  Writing, curating, or auditing an augustash shared or per-project memory —
  deciding whether something qualifies, which tier it belongs in, whether it's
  really a skill, how to word the index entry, and the commit/push steps that
  finish the write. Load it BEFORE saving a memory ("remember this", "save that
  for next time", noticing something worth keeping), before promoting a
  per-project memory to shared, and whenever a memory audit is triggered or the
  SessionStart staleness reminder fires. NOT for reading or recalling an
  existing memory — that's just opening the file the index points at — and not
  for authoring a skill's own procedure.
---

# Memory management

Two shared tiers, both committed to git so the whole team benefits:

- **Global** — `vendor/augustash/claude-config/memory/{topic}/{specific}.md`. Knowledge that
  transcends any single project: augustash internal modules, cross-project debugging
  approaches, team tooling conventions. Ships into every project requiring the package.
- **Per-project** — `.claude/memory/` in the project repo. Knowledge specific to one codebase:
  integration details, architectural decisions, non-obvious configuration.

Prefer both over Claude's local auto-memory (`~/.claude/projects/`) for anything worth sharing.

## 1. Does it qualify?

**The test: given a clear, direct prompt, would a fresh session still need to do real work to
arrive at this understanding?** Ignore how the current session went — messy communication and
high token spend don't mean the knowledge is complex. What matters is whether the knowledge
*itself* was non-trivial to discover.

Worth saving:

- **Cross-system synthesis** — understanding required connecting dots across multiple files,
  services, or external docs a fresh session would have to re-traverse.
- **Non-obvious reasoning** — the "why" behind a choice isn't in the code, and a future
  session would make the wrong call without it.
- **External context** — API behaviors, vendor quirks, team decisions living outside the
  codebase.

Not worth saving: anything a fresh session could resolve with a grep, a read, or a quick
command — even if this session took a long time to get there.

## 2. Which tier?

If the knowledge would help on a different augustash project, it's global. If it only matters
in this codebase, it's per-project. **When in doubt, per-project** — promotion is cheap, and
the promotion bar is the same "useful in ≥2 projects" rule used for patches.

Promotion means *authoring it in the `augustash/claude-config` repo*, not editing the local
`vendor/` copy in place and hoping.

## 3. Is it actually a skill?

Memory is knowledge to *recall* — a gotcha, a decision, a vendor quirk. A **skill** is a
procedure to *follow*: a multi-step job with its own method, traps, and deliverable, worth
loading only when that job comes up.

If you're writing a memory with numbered steps and a tool to run, it's a skill. Split the
difference where it genuinely exists: mutable state (a date, a status) stays a memory, the
procedure becomes a skill. This file is that split — the audit *date* lives in
[memory-audit.md](../../memory/preferences/memory-audit.md) because a SessionStart hook reads
it and because skills get **copied** into each project's `.claude/skills/`, so state stored in
a skill would diverge across every project on the first update.

## 4. Write it

Update an existing memory rather than creating a near-duplicate. Remove what's outdated. Keep
files focused — one idea per file, organized `{topic}/{specific}.md` (see
[memory-structure](../../memory/preferences/memory-structure.md)).

Every save is also a **curator pass**: scan the topic dir for existing coverage, normalize
shape and voice against its neighbours, and reconcile any contradiction in one place rather
than leaving two files disagreeing. See
[mission.md → Steward role at write time](../../memory/preferences/mission.md).

## 5. Write the index entry as a hook, not a summary

The index in `CLAUDE.md` is loaded into **every session, in full, forever**; memory bodies load
only when opened. That asymmetry is the entire design — it's what lets the corpus grow without
the per-session cost growing with it.

An index line therefore pays rent on every session that never needs it, and its only job is to
answer *"is this worth opening?"* Write the **trigger** — the symptom, the task, the thing
you'd be staring at — not the finding:

> ✅ `— a correct 301 sits in the table unreachable; retiring a node is three steps, not two`
>
> ❌ `— retiring a node is THREE steps: unpublish, redirect, delete the alias.
> RedirectRequestSubscriber runs processInbound() before findMatchingRedirect(), so …
> [+400 chars]`

The long form is worse *as an index*, not merely more expensive: it front-loads the conclusion
and buries the trigger, so the thing being pattern-matched against sits forty words deep.

**Aim for ~120 characters after the em dash; `generate-agents.py` fails over 250.** If it needs
more, that's the body's job — and being unable to name the trigger in one line is a sign the
memory itself is unfocused and wants splitting.

Resist restating the fix "so it's already loaded." That isn't a shortcut; it's the cost, paid
every session, whether or not the memory is ever used. This drifted once already: by 2026-07-30
entries had reached 1,100 characters and the index was 27 KB, most of a session's memory budget
spent on memories that session never opened.

## 6. Finish the write

For a **global** memory, `vendor/augustash/claude-config/` is a real git working copy (the
project installs it with composer's `prefer-source`):

1. Write or edit `memory/{topic}/{specific}.md`.
2. Update the `### Current global memories` index in `CLAUDE.md`.
3. Run `python3 vendor/augustash/claude-config/generate-agents.py` — it lints, then regenerates
   `AGENTS.md`. **Not an optional follow-up; it's part of the write.**
4. From inside the package: `git add -A && git commit && git push`. Other projects pick it up
   on their next `composer update augustash/claude-config`.

All four steps are Claude's job, including the push — this is a self-contained shared package
other projects depend on, so leaving local-only edits defeats the purpose. This differs from
project-level work, where **the developer commits**. Memory is Claude-owned and committed
autonomously; showing the diff first is optional transparency, not a required review gate.

**Sanity-check before writing global memory:**

- If `vendor/augustash/claude-config/.git` is missing (installed via dist, not source), don't
  write — edits get clobbered on the next composer run. Ask the user to
  `composer reinstall augustash/claude-config --prefer-source` first.
- If `git status` there shows `HEAD detached` (project still on a tagged constraint), commits
  won't push to a branch. Ask the user to switch the constraint to `dev-master` and
  `composer update` first.

## 7. Auditing

**Triggers.** Opportunistic: a memory-heavy session, stale refs surfacing, a dev request. Plus
a **daily floor** so the corpus never drifts more than 24h unseen — enforced by a SessionStart
hook ([templates/memory-audit-check.py](../../templates/memory-audit-check.py)) that reads
`last_audit` from [memory-audit.md](../../memory/preferences/memory-audit.md) and surfaces a
reminder when stale. The composer Plugin wires that hook into every project's
`.claude/settings.json` (`addAuditHook()`, idempotent), so the whole team gets it with no
per-project setup. Fold the audit into the session's work — not a separate ceremony.

**Pre-check first.** `git -C vendor/augustash/claude-config log --since=<last_audit>`. If
nothing changed, bump `last_audit` to today and move on; the cost of a daily cadence is that
the pre-check stays cheap.

**What to review:**

- Are referenced files, functions, modules still accurate?
- Is any memory now obvious from the codebase, and no longer worth keeping?
- **Has it been FIXED UPSTREAM? Then delete it.** A bug nobody can hit again is dead weight —
  it costs context every session and sends the next reader hunting a symptom that no longer
  exists. "Fixed" means *released upstream*, not repaired here: a bug we fix with a patch we
  carry is still live for every other project, and the patch needs maintaining. Keep those,
  explicit that the fix is a local patch pending release. So the deletion trigger is a
  release — for each memory whose fix is a local patch, does the patch still apply against the
  installed version? If upstream landed it, delete the memory and drop the patch.
- Have entries grown bloated — bodies *or* index lines (§5)? Can any be consolidated?
- Does any conflict with [mission.md](../../memory/preferences/mission.md) or
  [follow-site-conventions](../../memory/preferences/follow-site-conventions.md) — i.e.
  diary-shaped rather than watch-and-suggest?

**Structure — run `python3 generate-agents.py` and read its output.** It lints before writing
and exits non-zero on: a duplicated `##`/`###` heading, a memory or skill indexed twice, an
index entry pointing at a missing file, a file in `memory/` or `skills/` that no index lists,
and an index description over 250 characters. Silence means the indexes and the disk agree —
don't hand-verify what the script already covers.

That guard exists because prose alone didn't hold it. On 2026-07-29 `CLAUDE.md` had grown **two
`## Skills` sections**, each with its own `### Current skills` listing a different skill, so
either index read as complete while showing half. The cause was structural: the Skills section
sat ~140 lines below the memory index, far enough off-screen that adding a skill near the top
looked like starting a new one. Anything that splits an index recurs the same way, so the guard
is mechanical and runs on every write. The length check was added the next day for the same
reason — the hook-not-summary rule had been prose since the beginning and still drifted.

**Skills** get the same accuracy and conciseness pass: has one grown two topics that want
splitting? Does its `description:` frontmatter still say when it applies *and when it doesn't*?

**Per-project memories** (`.claude/memory/` in the current project): same staleness and
conciseness checks, plus — does anything here show up across multiple projects and deserve
promotion (§2)?

**After a pass,** update `last_audit` in
[memory-audit.md](../../memory/preferences/memory-audit.md) and commit it separately from any
content changes, so reverting a bad edit doesn't silently un-audit the corpus.

## 8. Self-refinement

If this process needs adjustment — wrong triggers, too noisy, missing something — update this
skill. It should evolve based on what actually catches issues.

---
name: Run cex before commit rounds, not partway through them
description: Kaza's rule — export config BEFORE splitting work into commits, because the first export after a gap carries earlier sessions' config too and you find out halfway through staging
type: feedback
---

**Run `drush cex` before you start committing, not once you're partway through.**

The config export is a **shared, accumulating surface**, not a per-change one. Active config
moves every time anyone touches a settings form, a component, a role — and none of that
reaches the export directory until someone runs `cex`. So the first export after any gap
carries **every unexported change since the last one**, not just yours.

**Why:** discovering that mid-commit is the expensive moment. You have already decided what
the commits are, and now the diff contains config you didn't write, can't attribute, and
have to judge one file at a time — while staging. Exporting first turns that into a decision
you take once, before any commit boundary is drawn.

**How to apply:**

1. `cex` **first**, before deciding commit boundaries.
2. Read the whole config diff and sort it: *my change* vs *inherited drift*.
3. Inherited drift is **its own commit**, not a rider on yours — same single-idea rule as
   [[commit-messages]]. It reverts cleanly that way; bundled, it doesn't.
4. Prune anything the project's own notes flag as unintended before it lands. A settings form
   can add keys nobody asked for, and an export is where they become permanent.

⚠ **Pruning the export doesn't fix the active config.** Where an entity re-derives its own
settings on save (Drupal's `Component::preSave()` discards a hand-set `plugins` key, for
instance), the drift is still live and the *next* `cex` re-exports it. Pruning buys the
current commit, not a fix — say which one you did.

On md this surfaced as six component configs and a `neo_build.info.yml` appearing in a diff
that was supposed to be one new user role: the `cex` needed for the role was the first export
since several earlier sessions.

See [[commit-handoff]] for who commits what.

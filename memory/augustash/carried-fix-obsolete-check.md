---
name: A carried fix that conflicts on merge may be obsolete, not just stale
description: "Before rebasing or resolving a conflict on a local fix carried against a fast-moving upstream — check whether the CODE it patched still exists. No matching upstream commit does not mean the bug is unfixed; upstream may have solved it differently, and the conflict is the tell."
type: reference
---

# A carried fix that conflicts on merge may be obsolete

Carrying a fix against an upstream that moves fast — Neo especially, which ran
**77 commits in a week** — means periodically reconciling it. The instinct on a
merge conflict is to resolve it and carry on. Check first whether the fix is
still needed at all.

**Grepping upstream commit subjects does not answer that.** Upstream rarely
describes a fix the way we did, and may have removed the problem while
refactoring something else entirely — so "no matching commit" reads as "still
broken" when it can equally mean "solved, differently".

**Ask instead whether the code the fix touched still exists**, then whether it
still has the defect. Both outcomes showed up in one sitting on
`neo_alchemist` (2026-08-08), with *neither* having a matching upstream commit:

- **Still live.** `massageFormValues()` was still being handed
  `$originalValue` unguarded at the same call site. A prop genuinely stored as
  a scalar is passed into a method typed for arrays, so it fatals — and every
  validation of that form runs through it, so Save breaks too. The `?? []`
  default looks like a guard and is not: it only covers *unset*, never a
  stored scalar. Kept, and pushed as a PR.
- **Obsolete.** A fix replacing an `empty($value[$name])` guard with
  `array_key_exists()` — to tell a stored `FALSE` from a key never written —
  had no counterpart commit upstream, but the guarded line **no longer existed
  at all**. Upstream had rewritten the path and arrived at `array_key_exists()`
  independently. Dropped.

**The conflict itself is the signal.** Both were carried against the same file
region; the one that conflicted was the obsolete one, because upstream had
edited exactly what it patched. A clean merge means upstream left that code
alone, which is weak evidence the bug survives; a conflict means upstream
touched it, which is the moment to re-read rather than resolve.

**How to apply:**

- Back the local commits onto a `backup/` branch before resetting anything, so
  "obsolete" stays reversible.
- Compare against upstream's **current file**, not its log.
- A carried `.patch` gets this for free: if the anchor is gone the patch fails
  to apply, and a failure is a prompt to re-check rather than to rewrite the
  hunk. A fix carried as a fork *commit* has no such alarm — it silently
  conflicts and invites resolution. Prefer a patch for anything we intend to
  drop on release.

Related: [[internal-package-distribution]] covers the different trap of a
vendor clone's stale `origin` ref reporting a fake "N commits ahead".
[[memory-audit]] carries the companion rule — a memory whose fix landed
upstream is deleted, and the release is the trigger.

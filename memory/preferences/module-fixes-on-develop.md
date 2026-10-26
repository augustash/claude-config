---
name: module-fixes-on-develop
description: In a module clone, commit fixes straight to develop and push — no feature branch; the dev opens the PR, and you match the upstream author's conventions
metadata:
  type: feedback
---

Fixing a jacerider/augustash module in its standalone clone (`~/Projects/<module>/`):

**Work directly on `develop`.** Commit there as the fix takes shape, push when it works. Do not
cut a `fix/…` branch and merge it back.

**Claude commits and pushes; the developer opens the PR.** This is a third ownership zone, and
it differs from the consuming project — see [[commit-handoff]], which keeps project-repo
commits with the developer. A module clone does not work that way.

**Why:** (Kaza, 2026-08-15) a feature branch buys exactly one thing — somewhere to park work
that cannot go on the mainline yet, because the mainline is protected or shared with a release
you must not disturb. Neither is true here: we own these repos and `develop` *is* the working
line. Without that constraint a branch adds a merge commit and a round trip and protects
nothing. *"Once we're done we push it, until then we get it working."*

## Match the author's conventions

The other half of the rule, and the easier one to miss: a change landing in someone else's
module should be indistinguishable from their own work. **Code, commits, comments — read what
is already there and copy it**, rather than importing this project's habits.

Concretely, on the neo modules: commit subjects are emoji + conventional-commit, e.g.
`🐛 fix(toolbar): include query parameters in active-link detection` — not the plain subjects
used in consuming projects. Check `git log` in the clone before writing the first one, and give
the same treatment to comment voice, formatting and naming.

**How to apply:** `git checkout develop`, pull, make the fix, match the surrounding conventions,
commit, push. Then hand the developer the repo and branch so they raise the PR. Reach for a
branch only when there is a real reason the change cannot sit on `develop` — and say what it is.

## Forks: sync before you apply

When the clone is a fork (e.g. `kazajhodo/exo` of `jacerider/exo`), bring it current **before**
writing anything into it: `git pull --no-rebase origin develop`, then merge the upstream's
`develop` (add the upstream as a remote if it is missing). Only then apply the change. A fork
that is behind upstream produces a PR built on stale code, and a version or context line that
moved upstream turns a clean fix into a conflict for the maintainer.

If the change was already made before syncing, stash it, sync, and pop it. Never rewrite a pushed
commit to tidy up (`--amend` + force push): put the correction in a follow-up commit. The PR's net
diff is what the maintainer reviews, and they can squash on merge.

**Why:** (Kaza, 2026-10-26) an exo fix was committed onto a fork one upstream version behind,
then narrowed. Tidying it meant a force push, which was refused; syncing first and following up
with a normal commit gave the same one-line PR without rewriting anything.

Note the clones are **snake_case** (`~/Projects/neo_toolbar`), matching the package name rather
than the kebab-case path used for augustash packages.

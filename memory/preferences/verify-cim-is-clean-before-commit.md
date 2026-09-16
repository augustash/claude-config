---
name: A clean cex is not a clean cim — verify the import is a no-op before committing config
description: "Dane's rule. cex only proves you wrote files out; it says nothing about whether importing them is a no-op. Pull the database of the environment you cannot break, then confirm `drush config:status` reports nothing before committing. And `ddev db` silently does nothing when a database is already present — without -f you are reading a stale local, which is worse than not checking."
type: feedback
---

**Exporting config proves nothing. Importing it is the check.**

`cex` writes active config to disk. It cannot tell you whether importing those files somewhere
else is safe, because it never compares against anywhere else. The question that matters —
*would `cim` change anything, and what?* — is only answered by asking `cim`.

**Why:** a config file can be present, correct-looking and committed while `cim` still plans
to delete and recreate the entity it describes, because the importer compares on `uuid`, not
on the machine name or the contents you are reading. You find that out on the environment
where the import finally runs, which is the one you least wanted to find it on. See
[[config-created-at-runtime-breaks-cim]] for the mechanism that produces it.

**How to apply**, before committing anything that touches `config/`:

1. **Pull the database of the environment you cannot break** — usually live. Local config
   drift is not a stand-in; an older database gives both false positives and false negatives.
2. `cex`, then sort the diff — see [[cex-before-commit]], which owns that step.
3. **`drush config:status` and confirm it is empty.** Not "looks fine" — empty. Anything left
   is a change `cim` will make on every environment, and you should be able to name why each
   one is there.
4. Only then commit.

⚠ **`ddev db` no-ops when a database is already present.** It counts tables and exits early
unless you pass `-f`:

```
ddev db -f          # actually pulls
ddev db -f -e=test  # a specific environment
```

Without `-f` it prints nothing on a non-interactive run and returns 0, so it looks like it
worked. Every config comparison you then make is against your old local database. This is the
failure that hurts most, because it produces confident, specific, wrong answers rather than
an obvious error. `ddev db` wraps `ddev pull pantheon-db --skip-files` and then runs
`ddev drush deploy -y` (updb, then cim) — so the pull also rehearses the deploy for you.

**Rehearse on data you cannot corrupt, not on an environment you have promised for review.**
An environment holding a copy of live is the honest rehearsal for live; running the import
there twice to "see what happens" is how a review environment goes down mid-review.

On kow 2026-09-01 all three failures landed in one session: config created by an update hook,
`cim` never verified, and a `config:status` read against a stale local because `ddev db` had
quietly done nothing.

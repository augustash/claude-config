---
name: pantheon-build-lag
description: "`terminus env:code-log` lists a commit as deployed while the webroot still serves the previous build, so a deploy or post-deploy script run in that window executes OLD code and reports success."
metadata:
  type: reference
---

# Pantheon's code log runs ahead of the build

Push, then `terminus env:code-log <site>.<env>` shows the new commit at the top. Run
`drush deploy` and whatever post-deploy scripts the change needs. Everything reports
success — against the code that was there **before** the push.

**Why.** On an Integrated Composer site a push starts a build, surfaced as a
`Sync code on "<env>"` workflow. The code log records the commit the moment it lands in
the git repo; the webroot keeps serving the last **successful build artifact** until that
workflow finishes. Measured on ar-md 2026-08-25: **218 seconds** between the commit
appearing in the code log and the files changing on disk.

⚠ **It is not a cache, so cache-clearing does not help.** `terminus env:clear-cache` and a
`drush cr` both "succeed" and change nothing, because the PHP on disk is genuinely the old
file. That is the part that misleads: the obvious explanation for "new code, old
behaviour" is opcache, and chasing it wastes the window.

## Why it is worse than a slow deploy

The scripts don't fail — **they run, and they report green.** They are the old code, so
they apply the old rules and assert the old expectations.

On ar-md the post-deploy pass ran against the previous `LocationGroup`, rewrote thirteen
stored links to a slug the same push had just retired, and printed *all checks green*:
the checks that would have caught it shipped in the commit that had not landed yet. Only
a stray label in the output (`/locations/service → /locations/service`) gave it away.

Idempotent scripts made that recoverable — a re-run after the build fixed twelve of the
thirteen and a targeted repair took the last. A script that is not safe to run twice would
have left no such option.

## How to apply

**Do not treat the code log as proof the code is running.** Either wait for the build:

```
terminus workflow:list <site>          # "Sync code on <env>" must read succeeded
terminus workflow:wait <site>.<env>    # blocks until the running workflow finishes
```

…or, better, **assert on the code itself** — read back something the push added, because a
file cannot be ahead of its own contents:

```
terminus remote:drush <site>.<env> -- php:eval \
  'print (int) method_exists(\Drupal\my_module\MyClass::class, "methodAddedInThisPush");'
```

A constant, a new method, or a string in a file all work. Prefer this to the workflow check
when a script is about to write content: it is the only test that cannot be satisfied by a
build that reports done while the artifact is still swapping in.

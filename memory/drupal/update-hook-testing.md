---
name: Update-hook testing — test the behavior, not the plumbing
description: For trivial idempotent config-merge hook_update_N / hook_post_update, skip update-path tests; cover the behavior the change drives instead. Reserve UpdatePathTestBase for real data migrations.
type: feedback
---

When a change adds a trivial, idempotent `hook_update_N` / `hook_post_update_NAME` — e.g. appending a value to a config array (a new tracking param, a default setting) — **don't write an update-path test for it.** Test the *behavior* the change enables instead, and let the update hook ship untested.

**Why:** An `UpdatePathTestBase` test needs a database fixture (a dump of the old site state) and mostly ends up exercising Drupal's update *runner* plus `array_merge` — not your logic. The maintenance cost (keeping the fixture alive) outweighs the value when the hook is a few idempotent lines guarded by an `in_array`/`array_unique`. The update hook is one-time *delivery plumbing*; the durable guard is a behavior test that proves the feature works (e.g. the middleware actually strips the new param so the page cache-keys on the clean URL). That test protects the feature against regressions in middleware, config schema, etc. — long after the hook has run once and become irrelevant.

**When update-hook tests *are* worth it:** non-trivial migrations — transforming entity data, restructuring config shape, branching logic where a bug silently corrupts data and there's no other safety net. There the fixture cost is justified because the blast radius is large and hard to catch by hand.

**How to apply:**

- Adding a config-merge update hook to an augustash module → add/extend a **kernel behavior test** for the feature and skip the update-path test. Verify the hook landed on a real site manually (`drush updatedb` then `drush cget`), which is the proportionate check.
- This matches `drupal_cache_protection`'s own convention: `update_10001`/`10002`/`10003` are untested, while `TrackingParamStripTest` covers the stripping behavior.
- Bounds the same way [[trust-contrib-tests]] does — spend the test budget on behavior we own, not on Drupal's update machinery doing its documented job.

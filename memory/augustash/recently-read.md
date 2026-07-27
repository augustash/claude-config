---
name: recently_read module (augustash fork)
description: augustash/recently_read is a hard fork we own, taken over because upstream's server-side session tracking poisoned page cache sitewide and maintainers closed the reports as works-as-intended; never re-sync with upstream
type: reference
---

`augustash/recently_read`. Repo: https://github.com/augustash/recently_read. Installs to `web/modules/community/recently_read` (composer type `drupal-custom-module`).

## Why we own it

This is a **hard fork, not a patch set**. The contrib module tracked "recently read" items in **server-side sessions for anonymous users**, which forces a session on every anon visitor and poisons page cache sitewide — the module is typically placed in a sidebar/footer block, so the damage is not scoped to one route.

Other developers reported this in the upstream issue queue. Maintainers responded that it **works as intended**. Rather than keep fighting it, augustash took the module over.

**Consequence:** do not "helpfully" re-sync with upstream, re-apply upstream releases, or swap back to `drupal/recently_read`. The divergence is the entire point. Upstream's design is the bug.

## What the fork does instead

Tracking moved to **localStorage**. The view's JS reads IDs client-side and passes them to an AJAX endpoint (`/ajax/recently-read/products/{ids}`), so no session is created and anonymous page cache stays intact.

## Related cache landmines

The `recently_read_list` cache tag is a `*_list` entity tag — it invalidates on **any** entity CUD of that type. On a commerce site this is brutal: see [[cachetags-garbage-collection]] (sisal's cachetags table hit 2.74M rows with `recently_read_list` responsible for 4.5M invalidations) and [[caching]] for the `*_list`-tag guidance generally.

Site-specific mechanics for sisal live in that project's `.claude/memory/infrastructure/caching.md`.

## Drupal 11

1.0.5 already declares `core_version_requirement: ^10 || ^11`. No work needed on a D11 upgrade.

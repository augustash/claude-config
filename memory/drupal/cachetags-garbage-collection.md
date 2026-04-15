---
name: Drupal cachetags table has no garbage collection
description: The cachetags table grows indefinitely and slows all cache operations — needs periodic truncation or a GC module. Affects all sites, especially high-traffic commerce.
type: project
---

Drupal's `cachetags` table accumulates rows and invalidation counts indefinitely. `drush cr` clears cache bins but never touches `cachetags`. This is true even with Redis — cache bins live in Redis but every cache read still queries `cachetags` in MySQL to verify tag validity.

**Why:** On sisal (commerce site), the table grew to 2.74M rows with `recently_read_list` at 4.5M invalidations. Every cache lookup bottlenecked on this table. Truncating it immediately made the admin responsive again.

**How to apply:** Build a reusable solution — either a lightweight module with a cron hook that truncates `cachetags` periodically, or a drush command, or prune tags above a certain invalidation threshold. Every augustash site would benefit. The airport site also has this issue (dev wrote custom cleanup code for it).

**Key insight:** Truncating `cachetags` is safe — it just forces cached items to be treated as stale and rebuilt on next access. Equivalent to a full cache rebuild but targeted.

**Next step:** Build this as a standalone augustash module or integrate into an existing one. Consider whether a simple periodic truncation is sufficient or if smarter pruning (e.g., remove tags with >100K invalidations) is better.

---
name: Object Cache Pro survives a database clone, so get_option lies
description: After a Pantheon content clone or any DB import that bypasses WordPress, Redis still holds pre-clone option values — wp-admin and get_option() both report them, and the site behaves accordingly
type: reference
---

A Pantheon **content clone** (`terminus env:clone-content`, or the dashboard's Clone) replaces
the database. It does **not** flush the target environment's Redis. Object Cache Pro keeps
serving pre-clone values, and because it is a persistent object cache, that can last
indefinitely — there is no TTL that reliably rescues you.

The same applies to any import that writes rows without going through WordPress: `wp db import`,
a mysql restore, a ddev pull.

**What it looks like.** Observed on aaiatrix 2026-08-12, minutes after cloning live → test:

```bash
wp option get wc_connect_taxes_enabled                 # yes   <- Redis, pre-clone
wp db query "SELECT option_value FROM wp_options
             WHERE option_name='wc_connect_taxes_enabled';"   # no    <- the cloned row
```

wp-admin agreed with the *cache*, showing the setting as enabled, so checking the UI confirms
the wrong answer rather than catching it. It reads as "the clone didn't take" — the giveaway
that it did is that everything else matches: row counts, order IDs, Action Scheduler entries.

**This is not cosmetic.** Plugins gate real behaviour on `get_option()`, so the site *behaves*
as the stale value says. WooCommerce Shipping & Tax's `is_enabled()` reads the option, and with
a stale `yes` it registers its tax-calculation hooks and writes rate rows — on an environment
whose database says it is off.

**Fix:** `wp cache flush` immediately after any clone or import, before trusting a single
setting. Make it part of the clone routine, not something you reach for once confused.

**How to apply:** Two rules fall out of this.

1. **Never diagnose a setting through `get_option()` or wp-admin right after a clone.** Query
   `wp_options` directly; that is the only read that reflects what was actually cloned. The
   one-command tell is the pair above disagreeing.
2. **Guard code for destructive operations must read the database, not the cache.** A migration
   or truncate that checks `get_option()` for a safety condition can be handed a stale value and
   fail in the dangerous direction — clearing a guard that should have blocked it. Where a
   plugin's *behaviour* is what matters rather than its setting, test the behaviour: introspect
   `$wp_filter` for the plugin's callbacks instead of reading its option, since that reflects
   what actually got registered this request.

Related: [[woocommerce-pantheon-cache]] for Pantheon's *edge* cache (a different layer — this
one is the object cache), and [[wp-cli-silent-on-pantheon]] for the other way a Pantheon WP-CLI
run misleads you.

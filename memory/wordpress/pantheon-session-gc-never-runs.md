---
name: PHP session GC never runs on Pantheon
description: wp_pantheon_sessions grows to millions of rows and hundreds of MB because session.gc_probability is 0, so the plugin's collector is never called; the table can be most of the database
type: reference
---

**Symptom.** The database is far larger than the content justifies, and `wp_pantheon_sessions`
is the biggest table in it. On atr it was **694 MB across 2.76M rows** — a third of a 2 GB
database, with `wp_aioseo_cache` making up most of the rest.

**Cause.** `wp-native-php-sessions` implements collection correctly —
`inc/class-session-handler.php`:

```php
public function gc( $maxlifetime ) {
    $wpdb->query( ... "DELETE FROM $wpdb->pantheon_sessions WHERE `datetime` <= %s" ... );
}
```

Nothing ever calls it. That method is invoked only by PHP's native session garbage collector,
which fires with probability `session.gc_probability / session.gc_divisor`. On Pantheon
`session.gc_probability` is **0**, so the probability is zero and `gc()` has never run.

**Confirm from the data, not the config** — a container's `php -i` is not proof of what live
does. With `gc_maxlifetime` at its 1440-second default, a single pass would delete everything
older than 24 minutes. If rows months old are still present, collection has never happened:

```sql
SELECT MIN(datetime), MAX(datetime), COUNT(*) FROM wp_pantheon_sessions;
```

A `MAX(datetime)` far in the past means writes stopped too — usually a *fixed* bug where
anonymous requests were each spawning a session (bot traffic, cache-busting). The rows are
then pure fossil and every one is safe to collect.

## Fix

An mu-plugin, so a plugin update cannot revert it and nobody can deactivate it by accident.
Schedule a daily event calling the same DELETE:

- **Retention of a week, not 1440 seconds.** These rows back anything calling
  `session_start()` — multi-step forms, some checkout flows — and collecting one mid-flow
  loses that visitor's state. A week keeps the table trivially small anyway. WordPress auth is
  cookie-based, so this can never log anyone out of wp-admin.
- **Batch (~20k) and cap the batches per run.** The first pass is millions of rows; an
  unbounded DELETE holds one enormous transaction, and an uncapped loop will hit PHP's
  execution limit inside a cron request. Any remainder goes on the next run.
- Give the one-off backlog clear-out its own script that calls the *same* collector, so the
  scheduled path and the manual path cannot drift apart.

`wp_woocommerce_sessions` is worth checking in the same pass — WooCommerce ships
`cleanup_sessions()` and schedules it, but the action can sit failing, leaving a table that is
99% expired rows.

## Deleting rows does not shrink the file

InnoDB keeps the freed pages. Reclaiming disk needs `OPTIMIZE TABLE` as a second step, and the
distinction matters because the two have opposite risk profiles:

- Deleting is quick and safe at any hour.
- Rebuilding copies the table and needs temporary space roughly its current size.

Do them in that order and the rebuild is trivial — on a table you have just emptied there is
almost nothing to copy. Measured on atr: ~4 minutes of deletes, then **3.3 seconds** of
rebuilds across five tables. Reserving a quiet window for the rebuild is the wrong instinct;
the deletes are the slow part.

Watch for a table that is almost entirely *free space* rather than rows — `wp_aioseo_cache`
held 0.30 MB of live data in a 592 MB file, all churn fragmentation. `data_free` in
`information_schema.tables` is what exposes that; a row count will not.

Related: [[object-cache-survives-db-clone]], [[woocommerce-pantheon-cache]].

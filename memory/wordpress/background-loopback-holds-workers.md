---
name: background-loopback-holds-workers
description: WordPress plugins that index or queue by HTTP-calling the site itself (SearchWP, WP Background Processing) hold PHP-FPM workers per batch; on a small Pantheon plan that is the saturation.
metadata:
  type: reference
---

A plugin that does background work by `wp_remote_post()`-ing the site's own URL — SearchWP's
indexer, anything built on WP Background Processing, Action Scheduler's async runner — spends
**a PHP-FPM worker per batch, often two**: the request that dispatches waits on the one it
started. On Pantheon the call also leaves through the public hostname, so it goes out through
Cloudflare and back in ([[pantheon-loopback-through-cloudflare]]). On Basic (4 workers) one
indexing run is half the pool. Add bot traffic and every visitor queues: TTFB climbs, nginx
logs `worker_connections are not enough`, and Google's crawl stats see the same slow first byte.

## How it shows in the logs

- `php-fpm-error.log`: `server reached pm.max_children setting (4)` in clumps, and slow-request
  warnings naming `admin-ajax.php?action=searchwp_index_controller` (or the plugin's action).
- `php-slow.log`: stacks parked in `wp_remote_post()` under `searchwp/includes/BackgroundProcess.php`.
- Access log: `POST /wp-admin/admin-ajax.php` from the **appserver's own IP**, seconds each.

On ent (2026-11-11, 61 days): 562 SearchWP runs at 3.6s, the clumps landing whenever staff edited.

## SearchWP: index in the save request, sweep from WP-CLI

Pantheon sets `DISABLE_WP_CRON` and runs WP-Cron **hourly through WP-CLI**, in a container
outside the web pool — free for background work, but an hour of lag is too slow for search
(Kaza's call). **The fix ships in `augustash/wordpress-cache-protection` ≥ 1.1.0** (`SearchwpIndexing`,
on by default when SearchWP 4 is active; first on ent). Install that rather than copying code. Its shape:

- `searchwp\index\process\enabled` → only under WP-CLI. Web requests never dispatch.
- `searchwp\indexer\alternate` → true. Skips the blocking 0.5s HTTP self-test SearchWP runs on
  every save to pick its transport, and alternate mode never dispatches to continue.
- `searchwp\index\aggressive_delta` → true. A save drops the entry's index and status rows at
  once instead of queueing a delta.
- On `searchwp\index\drop`, remember the entry; on `shutdown`, `fastcgi_finish_request()` then
  re-index it as `wp searchwp index` does — insert the status row, `$index->add()`. Only ids in
  `$source->get_unhandled_ids(-1)`, so drafts and trashed posts stay out. ~20ms, the worker
  the save already held, searchable immediately.
- Hourly cron event calling `\SearchWP\CLI::index()`, guarded to WP-CLI, as the net.

Traps met building it:

- **`wp searchwp index` ignores the delta queue.** It destroys queued drops and indexes only
  entries with no status row, so with deltas queued an edited post is never re-indexed.
  `aggressive_delta` is what makes CLI indexing see edits.
- **`$index->add()` only UPDATEs the status row.** Insert it first or the entry indexes but
  reads as unhandled.
- **`drop_post` checks `current_user_can('edit_post')`.** A logged-out test save does nothing,
  which reads as the hook not firing.
- SearchWP's settings screen then says the indexer is **paused** — true for web requests. Expected.
- **A WP-CLI test can't simulate a web save.** SearchWP reads `process\enabled` once, building its
  indexer at `init` 99999, so an `add_filter` in `wp eval` lands too late; the CLI indexer then
  queues the entry itself and the re-index looks broken. Test with a real web request: a
  throwaway ddev mu-plugin endpoint that does `wp_set_current_user(1)` + `wp_update_post()`.
- **Deploying the code doesn't activate the plugin.** Activate it on each environment right
  after the deploy; until then SearchWP is back on self-calls.

Other loopback plugins need their own seam; the principle carries: do the work in a request
already holding a worker (after `fastcgi_finish_request()`) or under WP-CLI, never by calling
yourself. New seams for other plugins belong in wordpress-cache-protection beside SearchWP's.

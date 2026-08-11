---
name: terminus wp returns no output at all
description: Every WP-CLI command on a Pantheon site exits 0 and prints only warnings — the cause is an unguarded $_SERVER read in wp-config.php, not WP-CLI or terminus
type: reference
---

**Symptom.** `terminus wp <site>.<env> -- option get siteurl` prints a few PHP warnings, exits
**0**, and returns **no command output at all**. Same for every command — `eval`, `eval-file`,
`db query`, `plugin list`. The site itself serves fine over HTTP, and WP-CLI works normally in
ddev, so it reads like a terminus or platform fault.

```
Warning: Undefined array key "REQUEST_URI" in .../wp-cli/php/WP_CLI/Runner.php(1334) : eval()'d code on line 64
Warning: Undefined array key "REQUEST_URI" in .../wp-cli/php/WP_CLI/Runner.php(1334) : eval()'d code on line 78
Warning: Oops! The wp-native-php-sessions plugin couldn't start the session because output has
         already been sent.
```

**Reading the trace.** WP-CLI `eval()`s wp-config.php during bootstrap, so *"eval()'d code on
line N"* is **line N of wp-config.php** — not of any WP-CLI file. The warning is emitted while
config is loading, before WP-CLI installs its output handling; `wp-native-php-sessions` then
bails with "output has already been sent", and stdout stays corrupted for the rest of the run.
Commands still execute — you simply never see what they say.

**Cause — operand order in a redirect guard:**

```php
// wrong: && evaluates left to right, so REQUEST_URI is read before the guard short-circuits
if ($_SERVER['REQUEST_URI'] == '/legacy.htm' && php_sapi_name() != "cli") {

// right
if (php_sapi_name() != "cli" && $_SERVER['REQUEST_URI'] == '/legacy.htm') {
```

Under CLI there is no `REQUEST_URI`, so the left operand warns every time. The author usually
*knew* a CLI guard was needed — on atr all four blocks carried the comment "Check if Drupal or
WordPress is running via command line" — and just put it second.

**Why it is rare.** The stock Pantheon upstream guards the **wrapper**, so nothing inside can
reach `$_SERVER` under CLI:

```php
if (isset($_ENV['PANTHEON_ENVIRONMENT']) && php_sapi_name() != 'cli') {   // guard here
    header('Location: https://' . $primary_domain . $_SERVER['REQUEST_URI']);
```

It breaks when someone hand-adds legacy redirects under a wrapper that **dropped** the
`php_sapi_name()` check, then re-adds the guard inline on each `if` — backwards. A scan of 39
augustash WordPress sites (2026-08-11) found 11 on the stock pattern, 1 with the backwards
operand still protected by an intact outer guard (inert), and **1 genuinely broken**. So: not a
common mistake, but invisible where it exists, because nothing about the site misbehaves.

**Why it matters more than a cosmetic warning.** Anything that shells out to `wp` on Pantheon —
Quicksilver hooks, scheduled tasks, deploy automation — has been running with mangled output
the whole time, silently. And a destructive `wp eval-file` run in this state executes **blind**:
no report, and `WP_CLI::error` aborts look identical to `WP_CLI::success`. Never run a
migration or truncate through `terminus wp` until you have seen it return real output.

**How to apply:** When `terminus wp` returns nothing, don't debug terminus or WP-CLI — read the
warning's line number as a wp-config.php line number and look for `$_SERVER` accessed before a
`php_sapi_name()` guard. `grep -n 'REQUEST_URI' wp-config.php` finds it in one shot; confirm the
enclosing wrapper carries the CLI check rather than assuming an inline guard is doing the job.
Generalises to any unguarded superglobal read in wp-config.php — `HTTP_HOST` and `HTTPS` fail the
same way. Related Pantheon-environment traps: [[aioseo-llms-txt-static-file]] (read-only docroot
on test/live) and [[woocommerce-pantheon-cache]].

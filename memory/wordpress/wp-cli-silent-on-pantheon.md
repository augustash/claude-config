---
name: terminus wp returns no output at all
description: Every WP-CLI command exits 0 and prints nothing — usually because composer installed the WP-CLI framework without its command bundle, so eval/eval-file/option/db do not exist and fail silently
type: reference
---

**Symptom.** `terminus wp <site>.<env> -- option get siteurl` exits **0** and returns **no
output whatsoever**. Same for `eval`, `eval-file`, `db query`, `plugin list`. The site serves
fine over HTTP. Nothing indicates failure — which is the dangerous part.

## Cause 1: framework-only WP-CLI (the common one)

`composer.json` requires the WP-CLI **framework** rather than the bundle:

```json
"wp-cli/wp-cli": "^2.10"          // framework only — cli + help, nothing else
"wp-cli/wp-cli-bundle": "^2.10"   // what you actually want: eval, eval-file, option, db, core...
```

`vendor/bin/wp` then **shadows** the platform's own WP-CLI (Pantheon's, or ddev's at
`/usr/local/bin/wp`), so you get a binary that reports a healthy `WP-CLI 2.10.0` but has almost
no commands. An unregistered command normally errors — but with plugins loading, that error is
swallowed, leaving pure silence.

**Diagnose in two commands:**

```bash
wp cli version                    # works — `cli` lives in the framework, no WP bootstrap
wp option get siteurl             # silent — `option` is in entity-command, not installed
wp option get siteurl --skip-plugins   # NOW it says: 'option' is not a registered wp command
wp help --skip-plugins --skip-themes   # the real inventory: cli, help, and little else
```

`--skip-plugins` is what turns the silence into the actual error message. Reach for it first.

**Fixes:** add `wp-cli/wp-cli-bundle` to composer; or call the platform binary explicitly
(`ddev exec /usr/local/bin/wp …`) to sidestep `vendor/bin/wp`; or, if you only need one job run
and don't want to touch dependencies, register it as a custom command from an mu-plugin —
`WP_CLI::add_command()` is in the framework, so custom commands work even with no bundle.

## Cause 2: unguarded $_SERVER in wp-config.php

A second, independent way to lose output — worth knowing because it produces warnings that look
like the cause but aren't:

```
Warning: Undefined array key "REQUEST_URI" in .../WP_CLI/Runner.php(1334) : eval()'d code on line 64
Warning: Oops! The wp-native-php-sessions plugin couldn't start the session because output has
         already been sent.
```

WP-CLI `eval()`s wp-config.php, so *"eval()'d code on line N"* is **line N of wp-config.php**.
The usual culprit is operand order in a hand-added redirect:

```php
// wrong: && evaluates left to right, so REQUEST_URI is read before the guard short-circuits
if ($_SERVER['REQUEST_URI'] == '/legacy.htm' && php_sapi_name() != "cli") {
// right
if (php_sapi_name() != "cli" && $_SERVER['REQUEST_URI'] == '/legacy.htm') {
```

The stock Pantheon upstream guards the **wrapper** instead, so nothing inside can reach
`$_SERVER` under CLI — `if (isset($_ENV['PANTHEON_ENVIRONMENT']) && php_sapi_name() != 'cli')`.
It only breaks where someone hand-added redirects under a wrapper that dropped the CLI check. A
scan of 39 augustash WordPress sites (2026-08-11) found exactly one genuinely broken and one
inert. Fixing this clears the warnings but **does not** restore output if Cause 1 is also
present — they are independent, and atr had both.

**How to apply:** Never run a destructive `eval-file` (migration, truncate, bulk update) through
`terminus wp` until you have seen that command return real output on that environment — a
missing command and a completed run are indistinguishable at exit 0, and `WP_CLI::error` aborts
look exactly like `WP_CLI::success`. Verify with `wp help --skip-plugins` first. Related
Pantheon-environment traps: [[aioseo-llms-txt-static-file]] (read-only docroot on test/live) and
[[woocommerce-pantheon-cache]].

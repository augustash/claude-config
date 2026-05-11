---
name: Drupal PHPUnit testing in DDEV
description: How to set up and run PHPUnit kernel/unit tests in Drupal projects using DDEV
type: reference
---

## Setup

**Projects typically do not ship with `drupal/core-dev` in `require-dev`.** Check `composer.json` before attempting to run tests — you'll usually need to add it. Symptom: `vendor/bin/phpunit` missing, `composer show phpunit/phpunit` reports "not found." This has come up repeatedly; confirm the install state before writing tests so you can flag it early.

1. **Install test dependencies — pin to the project's drupal/core major.minor:**
   ```
   ddev composer require --dev "drupal/core-dev:^10.6" --no-update
   ddev composer update drupal/core-dev --with-all-dependencies
   ```
   - **Do NOT use `composer require --dev drupal/core-dev --update-with-all-dependencies` without a version constraint.** Composer will try the latest (e.g. 12.x-dev) and fail with dozens of "requires drupal/core ^N but these were not loaded because they are affected by security advisories" errors that are really version-conflict errors in disguise. The fix is to pin to the major.minor of the installed core. Check with `ddev composer show drupal/core` first.
   - Do NOT just install `phpunit/phpunit` alone — Drupal's test bootstrap requires Behat/Mink and other deps from `drupal/core-dev`.
   - May need to allow additional composer plugins: `phpstan/extension-installer`, `php-http/discovery`, `dealerdirect/phpcodesniffer-composer-installer`.

2. **Create `web/core/phpunit.xml`** from `web/core/phpunit.xml.dist` with DDEV values:
   - `SIMPLETEST_BASE_URL` = `http://{project}.ddev.site`
   - `SIMPLETEST_DB` = `mysql://db:db@db/db`
   - `BROWSERTEST_OUTPUT_DIRECTORY` = `../sites/simpletest/browser_output`
   - Keep `bootstrap="tests/bootstrap.php"` (relative to core/)
   - Optionally disable deprecation notices: `SYMFONY_DEPRECATIONS_HELPER` = `disabled`

3. **Create browser output dir** (for functional tests): `ddev exec mkdir -p /var/www/html/web/sites/simpletest/browser_output && ddev exec chmod -R 777 /var/www/html/web/sites/simpletest`
   - You may still see `HTML output directory ../sites/simpletest/browser_output is not a writable directory.` warnings when running kernel tests. This is a known phpunit cwd-vs-xml-path quirk and is non-blocking for kernel/unit tests — tests still run. Only worry about it if you're running functional tests.

## Running tests

**Critical:** Run from `web/` directory, not project root. Kernel tests spawn subprocesses that look for `phpunit.xml` relative to `core/`, so running from project root causes "Could not read phpunit.xml" errors.

```bash
# Run a specific module's tests (path varies: modules/custom/, modules/contrib/, etc.)
ddev exec bash -c "cd /var/www/html/web && ../vendor/bin/phpunit -c core modules/{custom,contrib}/my_module/tests/"

# Run a specific test class
ddev exec bash -c "cd /var/www/html/web && ../vendor/bin/phpunit -c core modules/custom/my_module/tests/src/Kernel/MyTest.php"

# Run by group
ddev exec bash -c "cd /var/www/html/web && ../vendor/bin/phpunit -c core --group my_group"
```

## Service decoration gotcha

When you decorate a tagged service in Drupal 10+ / Symfony 5+, **tags on the decorated service are copied to the decorator automatically**. Do not redeclare them on the decorator — the decorator ends up registered twice for every tag, which for things like order processors means every promotion applies twice, every event handler fires twice, etc. The symptom in tests is "asserted size 1, actual size 2" on adjustments or event-driven collections. If you discover this mid-refactor, removing the redundant `tags:` block from the decorator's services.yml is the fix.

## Mock argument auto-fill gotcha

PHPUnit's generated mocks pass **every signature parameter** to the invocation handler — including ones the caller didn't provide, filled in with their declared defaults. So `$mock->condition('f', 5, '=')` against `condition($field, $value = NULL, $operator = NULL, $langcode = NULL)` records 4 args (`['f', 5, '=', NULL]`), not 3. Same for `sort('changed', 'ASC')` → `['changed', 'ASC', '']` because of `$langcode = ''`.

Bites variadic capture callbacks:
```php
$mock->method('condition')->willReturnCallback(fn(...$args) => $calls[] = $args);
// $calls captures the trailing defaults, not just what the caller passed.
```

Fix by truncating to the leading N positions you care about (`array_slice($args, 0, 3)`), or assert against the full mock-emitted shape including defaults. **Don't `array_filter` to drop NULLs** — it strips legitimate NULL args too.

Also: PHP arrays return by value. If a helper builds a `$calls = []` and returns it from a closure-mutated variable, the caller gets a snapshot taken at return-time, not the live array. Pass `array &$calls` by reference into the helper instead.

`withConsecutive()` is deprecated in PHPUnit 9.6 (removed in 10). Combined with `failOnWarning="true"` from `phpunit.xml.dist`, it can fail tests on a deprecation notice. Capture-and-assert is the cleaner replacement for verifying multiple calls with different args.

## Group convention

Every custom test carries `@group aai` as its umbrella plus at least one module-specific group — see [test-tags.md](test-tags.md) for the cross-runner convention (also applies to Nightwatch).

```php
/**
 * @group aai
 * @group my_module
 */
class MyTest extends KernelTestBase { ... }
```

**Always pass explicit paths to `--group aai` — every dir under `modules/` *except* `contrib`.** Bare `--group aai` forces phpunit to scan the entire test tree (core + every contrib) just to discover groups, and one broken contrib test file kills the run — `rdf`'s migrate tests are a known offender (`Declaration of ::testMigrateUpgradeReviewPage() must be compatible with ...`). When running our tests we never want contrib/core tests anyway.

Typical augustash projects split modules across `modules/custom` and `modules/community`; some have extra dirs. Pass each non-contrib path:

```bash
ddev exec bash -c "cd /var/www/html/web && ../vendor/bin/phpunit -c core --group aai modules/custom modules/community"
```

Check `ls web/modules/` before running — if the project has other non-contrib dirs alongside `custom`/`community`, add them too. The rule is "everything except `contrib`."

## Do not use `--list-groups`

**Do not use `--list-groups`** to explore available groups. It scans every test file in the tree, including contrib modules, and commonly dies on poorly-maintained contrib test files (missing trait references, undefined variables in Unit tests, etc.). Target a specific path instead — kernel/unit tests under `modules/custom` or `modules/contrib/{module}/tests/src/Kernel` run fine because phpunit only loads the files it actually needs.

Source: https://www.drupal.org/docs/develop/automated-testing/phpunit-in-drupal/running-phpunit-tests

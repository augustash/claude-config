---
name: Drupal PHPUnit testing in DDEV
description: How to set up and run PHPUnit kernel/unit tests in Drupal projects using DDEV
type: reference
---

## Setup

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

## Do not use `--list-groups`

**Do not use `--list-groups`** to explore available groups. It scans every test file in the tree, including contrib modules, and commonly dies on poorly-maintained contrib test files (missing trait references, undefined variables in Unit tests, etc.). Target a specific path instead — kernel/unit tests under `modules/custom` or `modules/contrib/{module}/tests/src/Kernel` run fine because phpunit only loads the files it actually needs.

Source: https://www.drupal.org/docs/develop/automated-testing/phpunit-in-drupal/running-phpunit-tests

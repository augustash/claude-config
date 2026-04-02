---
name: Drupal PHPUnit testing in DDEV
description: How to set up and run PHPUnit kernel/unit tests in Drupal projects using DDEV
type: reference
---

## Setup

1. **Install test dependencies:** `ddev composer require --dev drupal/core-dev --update-with-all-dependencies`
   - Do NOT just install `phpunit/phpunit` alone — Drupal's test bootstrap requires Behat/Mink and other deps from `drupal/core-dev`.
   - May need to allow additional composer plugins: `phpstan/extension-installer`, `php-http/discovery`, `dealerdirect/phpcodesniffer-composer-installer`.

2. **Create `web/core/phpunit.xml`** from `web/core/phpunit.xml.dist` with DDEV values:
   - `SIMPLETEST_BASE_URL` = `http://{project}.ddev.site`
   - `SIMPLETEST_DB` = `mysql://db:db@db/db`
   - `BROWSERTEST_OUTPUT_DIRECTORY` = `../sites/simpletest/browser_output`
   - Keep `bootstrap="tests/bootstrap.php"` (relative to core/)
   - Optionally disable deprecation notices: `SYMFONY_DEPRECATIONS_HELPER` = `disabled`

3. **Create browser output dir** (for functional tests): `ddev exec mkdir -p /var/www/html/web/sites/simpletest/browser_output && ddev exec chmod -R 777 /var/www/html/web/sites/simpletest`

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

Source: https://www.drupal.org/docs/develop/automated-testing/phpunit-in-drupal/running-phpunit-tests

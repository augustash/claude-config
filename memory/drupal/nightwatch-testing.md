---
name: Drupal Nightwatch testing setup
description: Running Drupal Nightwatch tests against DDEV with selenium-standalone-chrome — add-on, patch, yarn install, tag-scoped runs.
type: reference
---

## One-time setup per project

1. **Selenium container** — install the DDEV add-on that ships a chromedriver-capable Selenium container:
   ```
   ddev get ddev/ddev-selenium-standalone-chrome
   ddev restart
   ```
   This drops `.ddev/config.selenium-standalone-chrome.yaml` which wires the `DRUPAL_TEST_WEBDRIVER_*` env vars for Nightwatch to reach the selenium container. No `.env` edit needed — env vars are injected at the container level.

2. **Nightwatch W3C patch** — Drupal 10.x core Nightwatch does not natively handle W3C webdriver mode that selenium-standalone-chrome uses, so `sendKeys(ENTER)` and similar fail without the backport of [#3421202](https://www.drupal.org/project/drupal/issues/3421202).

   A vetted copy lives at `~/claude-config/patches/3421202-nightwatch-w3c-backport.patch`. Copy it into the project's `patches/` dir and add to composer.json:
   ```json
   "patches": {
     "drupal/core": {
       "Nightwatch W3C webdriver support (backport of #3421202).": "patches/3421202-nightwatch-w3c-backport.patch"
     }
   }
   ```
   Then `ddev composer install` to apply. If the project doesn't have `cweagans/composer-patches` yet, add that first (see existing drupal projects' composer.json for the full plugin wiring — `enable-patching`, `composer-exit-on-patch-failure`, allow-plugins entry).

3. **Yarn deps** — core's Nightwatch uses yarn:
   ```
   ddev exec 'cd /var/www/html/web/core && yarn install'
   ```

4. **`drupal/core-dev`** — Nightwatch also depends on `drupal/core-dev` being installed (see `drupal/phpunit-testing.md` for the install-with-pinned-major-minor recipe). Projects typically don't ship with it.

## Running tests

From the host:
```
# Everything in a module's tree
ddev exec 'cd /var/www/html/web/core && yarn test:nightwatch /var/www/html/web/modules/custom/my_module/tests/'

# Scoped by @tags (preferred — faster, and you already tag your suites)
ddev exec 'cd /var/www/html/web/core && yarn test:nightwatch --tag my_group'
```

## Test structure

Tests live at `<module>/tests/src/Nightwatch/Tests/*.js` and run against the live DDEV site — no drupalInstall/Uninstall — so they exercise the real theme, JS libraries, and content. Tests must not mutate site state or there's nothing to clean up.

Shared test logic is best expressed as factory functions in a `helpers/` sibling directory that return Nightwatch test callables, composed into each test file's `module.exports`. JS's object-literal test modules don't support class-style inheritance, so composition beats "base class."

## Gotchas

- **EU cookie banner overlays the submit button.** Nightwatch `.click()` fails on intercepted clicks. Inject a `display: none` stylesheet in `beforeEach` for `#sliding-popup, .cn-body, .eu-cookie-compliance-banner`.
- **URL assertions should be structural.** Exo's filter encoding is base64+json — assert `urlContains('q=')` and `urlContains(expectedPath)`, never the full encoded value.
- **Row-count assertions are fragile** against live content. Assert "list is present" or "at least one row" rather than specific counts or titles.
- **W3C mode + `click()` on intercepted elements** will surface as "Element click intercepted" errors. The fix is usually (a) the cookie banner, or (b) a modal that hasn't finished opening — add a short `.pause(500)` after modal triggers.

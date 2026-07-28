---
name: Augustash test tag/group convention
description: Every custom test (PHPUnit, Nightwatch, or Playwright) carries the umbrella tag of the COMPANY that built the site — aai (August Ash) or ar (AshenRayne) — plus at least one module/concept sub-tag
type: feedback
---

Every hand-authored test in a project — PHPUnit (`@group`), Nightwatch (`@tags`), or Playwright (in-title `@tag` strings) — must carry **the umbrella identifier of the company that built the site**, plus at least one module- or concept-specific sub-tag. Applies to kernel, unit, functional, Nightwatch, and Playwright UI tests alike.

**Which umbrella depends on who built the site, not on the client:**

- **`aai`** — August Ash Inc. The larger team.
- **`ar`** — AshenRayne. A two-person shop: the developer and Cyle (the jacerider/neo maintainer), and nobody else. Both of them also work at August Ash, so the same person moves between both and the tag is what tells the sites apart.

**How to tell:** the Pantheon sitename is prefixed with it. Read `.ddev/config.yaml` — the site var (`DDEV_PANTHEON_SITE`, or its older `PANTHEON_SITE` / `project=` spellings, see [[ddev-drupal-pantheon-site-var]]) reads `aai-<slug>` or `ar-<slug>`. Magnum Dimensions / DMX Power is `DDEV_PANTHEON_SITE=ar-md` → **`ar`**.

Don't infer it from the client name or the repo directory, and don't assume `aai` because the shared config lives under `augustash/`. Check the prefix, or match an existing test in the project; ask if there is neither. Everything below writes `aai` as the example — substitute whichever applies.

**Why:** there's no native way to say "run all our custom tests" — bare `phpunit` or `yarn test:nightwatch` runs contrib and core suites too (slow and not our concern); Playwright runs in its own universe but benefits from the same filterability. A shared `aai` umbrella gives one stable target. Sub-tags keep per-module/concept targeting available for focused work.

**Applying to new tests:**

PHPUnit — class level, aai first. **Drupal 11** (PHPUnit 11) uses attributes; doc-comment metadata still works but is deprecated and is removed in PHPUnit 12:
```php
use PHPUnit\Framework\Attributes\Group;

#[Group('aai')]
#[Group('my_module')]
class MyTest extends KernelTestBase { ... }
```

**Drupal 9/10** (PHPUnit 9) has no attribute support — use the docblock there:
```php
/**
 * @group aai
 * @group my_module
 */
class MyTest extends KernelTestBase { ... }
```
Either way `--group aai` filtering is unchanged.

Nightwatch — module.exports `@tags` array, aai first:
```js
module.exports = {
  '@tags': ['aai', 'my_module', 'feature_slice'],
  // ...
};
```

Playwright — append tag strings to the test title (Playwright filters via `--grep`). Use `@aai`, `@aai-ui` (UI suite qualifier), then concept tags:
```js
test('hamburger opens panel @aai @aai-ui @menu', async ({ page }) => { ... });
test('icon hit-tests cleanly @aai @aai-ui @obstruction', async ({ page }) => { ... });
```

**Running all custom tests:**

```
# PHPUnit
ddev exec bash -c "cd /var/www/html/web && ../vendor/bin/phpunit -c core --group aai"

# Nightwatch
ddev exec 'cd /var/www/html/web/core && yarn test:nightwatch --tag aai'

# Playwright
cd tests/ui && npx playwright test --grep '@aai'
cd tests/ui && npx playwright test --grep '@aai-ui'   # UI subset only
```

No single command runs all three — each runner targets its own universe. The shared umbrella means a future wrapper script can aggregate them by piping through each runner's tag filter.

**Type qualifiers (alongside `aai`, never replacing it):**
- `aai-php` / `aai-js` — when a project needs to split PHP vs JS test universes inside a single runner.
- `aai-ui` — Playwright UI tests that hit a live URL and exercise the rendered front-end (separate from PHPUnit/Nightwatch which run inside the Drupal stack). Different operational profile (npm runner, no Drupal bootstrap, deploy-dependent), so worth distinguishing.

**Sub-tag shape:** typically `module_machine_name` for PHPUnit/Nightwatch tests covering module logic; concept-level (`menu`, `obstruction`, `checkout`) for Playwright UI tests where the behavior crosses modules. Order is conventional (`aai` first, `aai-*` qualifier next, concept/module last) — runners don't care, but consistency aids readability.

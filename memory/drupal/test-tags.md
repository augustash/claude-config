---
name: Augustash test tag/group convention
description: Every custom test (PHPUnit or Nightwatch) carries 'aai' as its umbrella plus at least one module-specific sub-tag, so `--group aai` / `--tag aai` runs all custom tests without pulling in contrib or core
type: feedback
---

Every augustash-authored test in a project — PHPUnit (`@group`) or Nightwatch (`@tags`) — must carry **`aai`** as its umbrella identifier, plus at least one module- or feature-specific sub-tag. Applies to kernel, unit, functional, and Nightwatch tests alike.

**Why:** there's no native way to say "run all our custom tests" — bare `phpunit` or `yarn test:nightwatch` runs contrib and core suites too (slow and not our concern). A shared `aai` umbrella gives one stable target that cleanly separates our code's tests from everyone else's. Sub-tags keep per-module targeting available for focused work.

**Applying to new tests:**

PHPUnit — class-level docblock, aai first:
```php
/**
 * @group aai
 * @group my_module
 */
class MyTest extends KernelTestBase { ... }
```

Nightwatch — module.exports `@tags` array, aai first:
```js
module.exports = {
  '@tags': ['aai', 'my_module', 'feature_slice'],
  // ...
};
```

**Running all custom tests:**

```
# PHPUnit
ddev exec bash -c "cd /var/www/html/web && ../vendor/bin/phpunit -c core --group aai"

# Nightwatch
ddev exec 'cd /var/www/html/web/core && yarn test:nightwatch --tag aai'
```

No single command runs both — each runner targets its own universe. If a project later needs finer type separation (e.g., "all JS umbrella" vs "all PHP umbrella") add `aai-js` / `aai-php` alongside `aai`; do not replace it.

**Sub-tag shape:** typically `module_machine_name` at minimum. Add finer slices (`homepage`, `child`, `flights`) as helpful. Order is conventional (aai first, module next, finer last) — PHPUnit ignores order, Nightwatch doesn't care, but consistency aids readability.

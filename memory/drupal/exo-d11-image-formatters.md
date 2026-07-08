---
name: eXo image formatters — D11.4 ImageFormatter constructor break + fix pattern
description: D11.4 added an 11th arg (ImageDerivativeUtilities) to core ImageFormatter::__construct; exo formatters that subclass it (ExoImagineFormatter, ExoImageFormatter) ArgumentCountError on any image render. Fix = drop the __construct override, inject via create()/parent::create().
type: reference
---

# eXo image formatters — D11.4 ImageFormatter constructor break + fix pattern

Drupal **11.4** added an 11th constructor argument — `ImageDerivativeUtilities $imageDerivativeUtilities` — to core `ImageFormatter`. Any exo formatter that **subclasses `ImageFormatter` and overrides `__construct` to call `parent::__construct(...)` with a hardcoded arg list** breaks the moment an image field renders:

```
ArgumentCountError: Too few arguments to ImageFormatter::__construct(),
10 passed in .../ExoImagineFormatter.php and exactly 11 expected
```

A second, load-time landmine rides along: these subclasses also **redeclare `$currentUser` / `$imageStyleStorage` as untyped properties**. Core 11.4 made those **typed promoted** properties, so an untyped redeclaration is a fatal *when the class autoloads* (independent of the arg count) — "Type of X::$currentUser must be AccountInterface (as in class ImageFormatter)".

**The fix pattern (version-proof — this is what jacerider adopted upstream):** stop overriding the constructor entirely. Let core build the instance, then attach the exo-specific services via property injection in `create()`:

```php
public static function create(ContainerInterface $container, array $configuration, $plugin_id, $plugin_definition) {
  // Let the parent (core ImageFormatter) construct the instance so this stays
  // compatible across core versions that change the constructor signature.
  $instance = parent::create($container, $configuration, $plugin_id, $plugin_definition);
  $instance->exoImageSettings = $container->get('exo_image.settings');
  // ...remaining exo services...
  return $instance;
}
```

Also **delete** the now-redundant `$currentUser` / `$imageStyleStorage` property declarations (core owns them, typed) and the dead `use` imports the constructor pulled in.

**Status (as of exo `dev-develop` @ `901413a`, PR #76, 2026-07-08):**
- `exo_imagine/ExoImagineFormatter` — fixed upstream (this pattern).
- `exo_image/ExoImageFormatter` (deprecated formatter) — same break, still unfixed upstream at that commit; ported the same way and PR'd from the mymspconnect D11 upgrade.

When porting exo to D11.4, grep exo for `parent::__construct(` in `*Formatter*.php` and check each subclass of a core formatter whose constructor changed. See also [[exo-icon-kernel-tests]] for another "exo subclass assumes an older core shape" case.

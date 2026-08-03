---
name: eXo image formatters — D11.4 ImageFormatter constructor break + fix pattern
description: D11.4 added an 11th arg (ImageDerivativeUtilities) to core ImageFormatter::__construct; exo formatters in its ancestry (ExoImagineFormatter, ExoImageFormatter, ExoImagineMediaGalleryFormatter) ArgumentCountError or TypeError on any image render. Fix = drop the __construct override, inject via create()/parent::create(). Includes the two-grep sweep that catches indirect subclasses.
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

**Status (as of exo 2.0.19 / `develop` @ `9711c02`, 2026-08-03):**
- `exo_imagine/ExoImagineFormatter` — fixed upstream (this pattern), PR #76.
- `exo_image/ExoImageFormatter` (deprecated formatter) — ported the same way, PR'd from the mymspconnect D11 upgrade.
- `exo_imagine/ExoImagineMediaGalleryFormatter` — **still broken in 2.0.19**; fixed on `kazajhodo/exo` branch `fix/exo-imagine-media-gallery-d11-constructor` (`0e67a34`), PR'd to jacerider from the KOW D11 work.

## The third one is an *indirect* casualty — and the obvious grep misses it

`ExoImagineMediaGalleryFormatter` does **not** extend a core formatter. Its chain is
`Gallery → ExoImagineMediaFormatter → ExoImagineFormatter → core ImageFormatter`, and it
broke *because* the fix above landed: once the parents dropped their `__construct` overrides,
the gallery's own surviving `parent::__construct(...)` stopped hitting an exo constructor and
fell straight through to core's — passing its 13-arg list where core wants 11, so
`exo_imagine.settings` landed in slot #11:

```
TypeError: ImageFormatter::__construct(): Argument #11 ($imageDerivativeUtilities)
must be of type ?ImageDerivativeUtilities, Drupal\exo_imagine\ExoImagineSettings given
```

Note it's a **TypeError, not ArgumentCountError** — the arg counts happen to overlap, so the
type mismatch surfaces first. Grepping only for `ArgumentCountError` misses it.

**So the sweep is two greps, not one.** Find every `*Formatter*.php` that still calls
`parent::__construct(`, then walk each one's **full ancestry** to see whether a core formatter
sits at the root — filtering to classes that directly `extends ImageFormatter` skips exactly
this case. Fixing a base class can *create* this break in its subclasses, so re-run the sweep
after any such fix rather than assuming it's contained.

See also [[exo-icon-kernel-tests]] for another "exo subclass assumes an older core shape" case.

**Deploy trap:** on Pantheon-style projects `web/modules/contrib/` is gitignored, so a fix made
in the installed copy is local-only — it dies on the next `composer install` and never reaches
the server. Until the fix is tagged upstream, it has to ride as a `cweagans/composer-patches`
entry (see [[patches]]); a fork push alone changes nothing if composer still resolves the
package from the upstream repo.

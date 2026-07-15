---
name: Drupal 11.4 requires symfony/runtime allow-plugin = true
description: D11.4 adopted the Symfony Runtime component; its Composer plugin must be allow-listed as true (not false) or vendor/autoload_runtime.php is never generated and every web request WSODs — while drush still bootstraps and hides it.
type: reference
---

# Drupal 11.4 requires symfony/runtime allow-plugin = true

Drupal **11.4** adopted the Symfony Runtime component. `drupal/core ^11.4` now requires `symfony/runtime`, and the scaffolded `web/index.php` changed to:

```php
require_once 'autoload_runtime.php';
return static function () {
  return new DrupalKernel('prod', require 'autoload.php');
};
```

`symfony/runtime` ships a **Composer plugin**, so a `composer update` onto 11.4 triggers the `allow-plugins` prompt for it. It **must be enabled**:

```json
"config": { "allow-plugins": { "symfony/runtime": true } }
```

The plugin is what generates `vendor/autoload_runtime.php` during autoload dump. Set it to **`false`** (the tempting "just suppress the prompt" answer, and correct for older Symfony-runtime-using packages that Drupal didn't need) and the file is never created — so `web/index.php` fatals on every request:

```
PHP Fatal error: Failed opening required '.../vendor/autoload_runtime.php'
  web/index.php → web/autoload_runtime.php
```

**The trap:** this is a full anonymous WSOD, but `drush status`/`drush updatedb` still bootstrap fine (the CLI path doesn't go through `index.php`/the runtime), so the site looks alive from the shell while every browser hit 500s. Don't trust drush bootstrap as proof the site renders — curl a page.

**Fix:** flip `symfony/runtime` to `true`, then `composer install` (autoload dump re-runs the plugin and writes `vendor/autoload_runtime.php`). Watch for this specifically on **pre-11.4 → 11.4 bumps** where an existing `allow-plugins` already carries `symfony/runtime: false` as a reasonable-looking suppression — it silently becomes a WSOD the moment core crosses 11.4.

First hit: mymspconnect D10→D11 upgrade, 2026-07-08.

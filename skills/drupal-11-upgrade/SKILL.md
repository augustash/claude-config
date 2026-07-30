---
name: drupal-11-upgrade
description: Run a Drupal 10 → 11 upgrade on a Pantheon-hosted augustash site, from composer constraints through multidev verification. Covers the platform gates (MariaDB 10.6, symfony/runtime), the failure modes that report success (stale patches, drush bootstrapping over a WSOD), and the jQuery 4 / PHPUnit 11 fallout. Use when upgrading a site to D11, or when a D11 site behaves oddly after an upgrade. NOT for D9→D10, and not for routine minor-version bumps.
---

# Drupal 10 → 11 upgrade (Pantheon / augustash)

The upgrade itself is usually a one-day job. What costs days is a specific class
of failure: **things that report success while being broken.** Drush bootstraps
happily over a WSOD. Composer skips a patch without failing. `upgrade_status`
comes back clean while a constructor type error is waiting on the next request.
Most of this skill is about those.

## The one rule

**Never accept a drush exit code as evidence the site works.** `drush status`
reported a healthy `11.4.4` through an outage where *every page returned 500* —
twice, from two unrelated causes. After every significant step:

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://SITE/
curl -sk https://SITE/ | grep -oiE "the website encountered|TypeError|Fatal error"
```

A 61-byte response body means it died before Drupal could render an error page.

---

## Phase 1 — Platform gates (do these first, they block everything)

### MariaDB 10.6 is a hard requirement

D11 enforces `MARIADB_MINIMUM_VERSION = '10.6'`. **Pantheon's upstream pins
10.4** in `pantheon.upstream.yml`, so most sites are below it.

The trap: core only enforces this **at install time**, not at runtime. The site
appears to work on 10.4 — but every Kernel/Functional test fails, because tests
install a fresh Drupal. If a suite suddenly reports dozens of identical
failures, read one:

```
The database server version 10.5.29-MariaDB is less than the minimum required version 10.6
```

Fix, in `pantheon.yml` (overrides the upstream):

```yaml
database:
  version: 10.6
```

**Unquoted.** `'10.6'` as a string fails Pantheon's build validator.

Locally: `ddev utility migrate-database mariadb:10.6` migrates in place and
preserves data — it does *not* wipe the DB. (A `ddev db` post-start hook may
re-pull, but that is the hook, not the migration.)

Verify the platform actually moved before deploying anything else:

```bash
terminus drush SITE.ENV -- sqlq "SELECT VERSION();"   # expect 10.6.x
```

### symfony/runtime must be an allowed plugin

D11.4 adopted Symfony Runtime. If `symfony/runtime` is missing from — or `false`
in — `allow-plugins`, `vendor/autoload_runtime.php` never generates and **every
web request WSODs while drush still bootstraps fine**. Set it to `true` before
updating. See [[d11-symfony-runtime]].

### Other pantheon.yml items

- `php_version: 8.3` minimum.
- `drush_version` is **vestigial** when Drush is in composer with
  `build_step: true` — Pantheon always prefers site-local Drush. Values ≥11 are
  not even valid there. Remove the key rather than trying to raise it.

---

## Phase 2 — Composer

Constraints usually live in `upstream-configuration/composer.json` on Pantheon
upstreams, not the root `composer.json`. Bump `drupal/core-recommended`,
`drupal/core-composer-scaffold` and `pantheon-systems/drupal-integrations` to
`^11` there.

### Finding what blocks the resolve

Every D11 release below the newest is blocked by security advisories, so the
resolver has one viable target and the error output is a wall of advisory noise.
Filter it:

```bash
ddev composer update --with-all-dependencies --dry-run 2>&1 \
  | grep -vE "affected by security advisories|^\s*- drupal/core-recommended 11\."
```

Then look for the **first named package** in "Problem 1" — that is the blocker,
not the symfony/* lines beneath it, which are noise.

Look specifically for packages pinning core with an upper bound:

```bash
php -r '$l=json_decode(file_get_contents("composer.lock"),true);
foreach($l["packages"] as $p){ $c=$p["require"]["drupal/core"]??null;
if($c && str_contains($c,"<")) printf("%s %s => %s\n",$p["name"],$p["version"],$c); }'
```

On one site the sole blocker was `drupal/seven` (`>=10.3 <11.3`) — the admin
theme silently capping core two minors below target.

### Scraping drupal.org for compatibility is not enough

A `core_version_requirement` scrape of your **direct requires** is structurally
blind to:

- **transitive deps** (e.g. `votingapi` arriving via `fivestar`)
- **repo-committed modules** in `web/modules/custom|community` that are not
  composer packages at all

Read what is actually on disk instead — this is the check that finds them:

```bash
for d in web/modules/*/*/ web/themes/*/ web/themes/*/*/; do
  n=$(basename "$d"); f="$d$n.info.yml"; [ -f "$f" ] || continue
  cv=$(grep -m1 '^core_version_requirement' "$f" | sed 's/.*: *//' | tr -d "'\"")
  case "$cv" in *11*|">="*) ;; "") ;; *) echo "$n: $cv" ;; esac
done
```

Include `web/modules/custom/` and `web/themes/` — it is easy to scan only
`contrib/` and miss 30 of your own extensions. They keep working (Drupal only
blocks *installing* incompatible extensions) until a rebuild or re-enable fails.
`drush deploy`'s requirements check will list them; read that output.

Also note `>=9.4`-style open-ended constraints already satisfy D11 — the
drupal.org release-history `core_compatibility` field does not represent them,
so a scrape under-reports.

---

## Phase 3 — Patches (the expensive one)

### composer-patches only applies patches at package INSTALL time

This is the single most costly trap in this skill.

If a package's version and `dist.reference` are **identical** between the D10
and D11 locks, composer does not reinstall it, so **composer-patches never runs
for it**. On an incremental build (Pantheon reuses the artifact) the package
keeps whatever patch output it had — including patch content from before you
edited it.

Symptoms, all of which mislead:

- Build succeeds. `composer-exit-on-patch-failure: true` never fires, because
  no patch was *attempted* — nothing failed.
- The corrected patch file **is** present in the build.
- Other patches look fine — but only because their content never changed, so
  cached-and-patched is indistinguishable from freshly-patched.
- Only the patch whose **content** you edited is stale.

Diagnose by checking patch *output* on the build, not the patch file:

```bash
terminus drush SITE.ENV -- php:eval '
echo str_contains(file_get_contents("/code/web/modules/contrib/X/src/Y.php"), "NEW_SYMBOL")
  ? "patched" : "STALE";'
```

**Fixes that do NOT work** (all verified):

- editing the patch file — no reinstall, no re-apply
- renaming the patch / changing its description — same
- `composer update <pkg>` — "Nothing to modify in lock file"
- committing `patches.lock.json` — records intent, does not enforce
- upgrading to composer-patches **v2** — same install-time-only behaviour, and
  v2 additionally failed to apply patches v1 applied fine ("No available patcher
  was able to apply"), taking the whole install down

**The fix that works — two pushes:**

1. Remove the package from `composer.json` + lock. Push. Build **uninstalls** it
   from the artifact. *(Do not run `drush deploy` in this window — the module's
   config is still enabled while its code is gone. Config is safe as long as you
   never `pm:uninstall`.)*
2. Re-add it. Push. Build **installs fresh** → patches apply.

One commit doing both is a no-op: re-adding produces a byte-identical lock
entry, so composer sees no change.

**Prevention:** keep one patch file per package, regenerated wholesale rather
than a set of hand-edited files. Generate by diffing pristine against patched:

```bash
diff -ruN a/ b/ > patches/PKG-combined.patch   # a = pristine, b = patched
```

### `composer reinstall` is broken under composer-patches v1

The plugin removes **all** patched packages ("Removing package X so that it can
be re-installed and re-patched"), then composer's own reinstall fails with
"Package is not installed" — leaving core, commerce and everything else deleted.
Recovery is `composer install`. Prefer `composer install` over `reinstall`.

### Re-check every patch after any composer thrashing

Packages reinstalled during unrelated operations silently lose their patches.
Verify by grepping for a known symbol from each patch, not by trusting the log.

---

## Phase 4 — Runtime breakage that static analysis cannot see

`upgrade_status` is worth running (`--all --ignore-contrib`), but read it
correctly: its "Fix now" label means *next major*, not the one you are on. Check
the removal version in each message — `removed from drupal:12.0.0` is not a D11
blocker. On one site **zero** findings referenced removal in D11.

What it misses — and what actually breaks sites:

**Constructor / property type errors from parent classes gaining types.**
Two examples from one upgrade, both fatal, both invisible to PHPStan:

- a patched contrib class type-hinting `ContainerAwareEventDispatcher`, which
  D11 removed → `TypeError` at container-compile time
- a custom widget redeclaring `protected $entityTypeManager` untyped while the
  parent now declares `protected EntityTypeManagerInterface $entityTypeManager`
  → fatal on class load. Often paired with a stale `__construct` whose parent
  moved to `create()` property injection — remove both.

Find the second class systemically:

```bash
grep -rn "protected \$entityTypeManager;" web/modules/custom web/modules/community
```

**PSR-4 case mismatches.** `Case mismatch between loaded and declared class
names` surfaces only with Symfony's DebugClassLoader active (i.e. with
deprecation testing enabled). Works on macOS's case-insensitive filesystem,
fragile on Linux. Fix the filename **and** the `services.yml` reference together
— changing only one breaks the other environment. A case-only rename needs two
`git mv` steps.

---

## Phase 5 — jQuery 4

D11 ships **jQuery 4**, which removed long-deprecated APIs. Two distinct
problems:

### Removed utility functions

`$.isFunction`, `$.isArray`, `$.trim`, `$.isWindow` are gone. Unmaintained
vendored libraries still call them and throw, aborting their init — colorbox,
select2 and old jQuery UI plugins are common offenders. The visible symptom is
"a display looks slightly off", because a behaviour silently died.

Catch them by capturing real console errors, not by reading source:

```js
page.on('pageerror', e => errors.push(e.message));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
```

For **vendored** libraries you do not own, shim (eXo does this for pickadate in
`exo_form/lib/pickadate/jquery4-shim.js`). Attach via
`hook_library_info_alter()` so load order is guaranteed rather than hoped for.
For **your own** code, fix properly — native `.trim()`, `Array.isArray`,
`typeof x === 'function'`.

### jquery.once is gone

`core/jquery.once` was removed in **Drupal 10**. Libraries still declaring it
have an unresolvable dependency, and `$(sel).once('id')` throws unless something
(eXo ships a copy) happens to provide it. Migrate to `core/once`:

```js
// before
$(context).find(sel).once('id').each(function () { … $(this) … });
// after
once('id', sel, context).forEach(function (el) { … $(el) … });
```

Expect this to be **partially done** already on older sites, which is why the
breakage looks patchy. Grep both the library declarations and the call sites.

Do not take a jQuery *removal* as part of the upgrade. Drupal still ships it,
contrib requires it, and the regression surface is exactly the pages you can
least afford to break. Fix the removed APIs; leave the rest.

---

## Phase 6 — Config schema

D11 validates config against schema on save, so undeclared plugin settings
surface as warnings on every import and on any update hook that re-saves config.

Count **distinct schema definitions needed**, not raw key hits — one missing
definition is reported once per config entity using it, which inflates a
40-unit job into a 1000-key panic. Group by owning plugin before estimating.

Three distinct categories, needing different fixes:

1. **Genuinely missing schema** → write it, PR upstream
2. **Stale config from module refactors** → strip the dead keys (declaring
   schema for them would enshrine settings the code no longer reads)
3. **Type mismatches** → cast the values; checkbox settings stored as `0`/`1`
   need to be real booleans

Reuse parent types wherever a plugin subclasses a core/contrib one rather than
restating keys. Type genuinely non-enumerable structures (pluggable settings
forms, per-component UUID keys) as `type: ignore`.

Validate with core's own checker:

```php
$c = new class { use \Drupal\Core\Config\Schema\SchemaCheckTrait;
  public function r($t,$n,$d){ return $this->checkConfigSchema($t,$n,$d); } };
```

---

## Phase 7 — Tests

- **PHPUnit 11** deprecates doc-comment metadata → `#[Group]`, `#[CoversClass]`,
  `#[DataProvider]`. Hundreds of reported "deprecations" are usually two root
  causes: this, plus a stale XML schema.
- **Data-provider string keys are now named arguments.** A provider returning
  `'expected_theme' => …` against a `$expectedTheme` parameter fails with
  `Unknown named parameter`. Rename keys to match parameters exactly.
- **`phpunit --migrate-configuration` is not sufficient.** It updates the schema
  but drops `printerClass`/`<listeners>` **without** adding D11's `<extensions>`
  replacements, silently losing browser-test HTML output. See
  [[phpunit-testing]] for both templates.
- **Symfony 7 `RequestStack::getSession()` throws** instead of returning null.
  Kernel tests that hand-push a `Request` need a session attached, or core's
  `tearDown()` explodes.
- Commit the config as `phpunit.xml.dist`; a `custom` testsuite living only in
  the gitignored `phpunit.xml` cannot be run by CI or a fresh clone.

---

## Phase 8 — Pantheon deploy

Push code → Pantheon **builds**. `drush deploy` is a separate, later step. Do
not conflate them; the distinction matters during the two-push patch fix.

`drush deploy` runs `updatedb` → `cim` → `cr` → `deploy:hook` in the correct
order for a cross-version upgrade. Do not hand-run `cr`/`cim` before `updatedb`.

**Build guard:** Pantheon fails any build whose step produces files that are
neither committed nor gitignored:

```
The build step affected files that are not ignored by git:
?? patches.lock.json
```

Gitignore build output; do not delete a file the artifact still generates.

**Multidev Solr is empty even when the tracker says 100%.** The database (and
its tracker state) comes across; the Solr core does not. Reset and reindex:

```bash
terminus drush SITE.ENV -- search-api:reset-tracker global
terminus drush SITE.ENV -- search-api:index global
```

Then clear Drupal **and** edge caches, or pages rendered before the index stay
empty for up to the `max-age` (commonly 12h).

**Verify with a browser, not curl, for JS-rendered views.** An infinite-scroll
product index legitimately serves facets and a pager with zero product markup;
curl cannot tell that from a broken query.

---

## Deliverable / definition of done

- [ ] `pantheon.yml` — `database: version: 10.6` (unquoted), `php_version: 8.3`
- [ ] Platform DB actually reports 10.6.x on the target environment
- [ ] `symfony/runtime` allowed; `vendor/autoload_runtime.php` exists
- [ ] Every extension's `core_version_requirement` includes `^11` — custom and
      themes included
- [ ] Patch *output* verified on the build, not just the patch files
- [ ] Site **curled**, not just drush-statused; watchdog clean under a watermark
- [ ] Console errors captured on list + detail pages (jQuery 4 fallout)
- [ ] Custom test suite green
- [ ] Checkout exercised — via the `manual` gateway in tests, and by hand for
      real gateways, which tests deliberately never touch

## Related memory

[[d11-symfony-runtime]] · [[cross-version-db-pull]] · [[phpunit-testing]] ·
[[exo-d11-image-formatters]] · [[config-split-ignore-collision]]

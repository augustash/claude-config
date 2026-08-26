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

**Retiring Seven has a tail that lands weeks later.** Seven is gone from core in
11.0, so the deploy uninstalls it and switches the admin theme to Claro. The site
still works, so it reads as done — then the client reports the admin "looks
wrong": exposed filters that sat on one row wrap onto two, sidebar panels lose
their headers, favicons vanish. The cause is not styling. Modules that store
settings **keyed by theme machine name** (`exo_form.settings.themes`,
`real_favicon.settings.themes`) still have a `seven:` entry and no `claro:` one,
so their whole treatment silently stops applying. Sweep for it *during* the
upgrade rather than fielding it later:

```bash
grep -rn '\bseven\b' config/ | grep -viE 'seven_|\.seven|dependencies'
```

Copy the old theme's entry to the new key — see [[admin-theme-keyed-config]] for
the type gotcha and the residue that config alone can't fix. Budget an hour for
this; on one site it accounted for nearly the whole "we prefer the old admin
theme" complaint, and reverting the theme was never the answer.

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

**The patch procedure lives in [site-update](../site-update/SKILL.md), Phase 2** —
triage (merged upstream? did the code move? re-target), regeneration, and the
composer-patches install-time trap that makes an edited patch silently not apply.
An upgrade hits exactly the same wall as a routine round; it is not a different
procedure, so it is not duplicated here.

Read it before starting this phase. The two things an upgrade adds:

**The install-time trap is likelier here, and better hidden.** A D10→D11 lock
churns nearly every package, which makes it natural to assume everything was
reinstalled and therefore re-patched. Anything whose version and `dist.reference`
happened *not* to move was not — and on Pantheon's incremental build it keeps its
pre-edit patch output while the build reports success. That is the single most
costly trap in this skill; site-update has the diagnosis and the two-push fix.

**Budget for a patch sweep, not a patch fix.** Most patches on a D10 site were
written against D9/D10 code, so expect several to need re-targeting in one pass
rather than one to fail. Do the sweep before the multidev, and re-check every
patch after any composer thrashing — packages reinstalled during unrelated
operations lose their patches silently.

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

**A forked core plugin is a latent upgrade bug.** Custom widgets, formatters and
handlers that were copy-pasted from core to change one detail keep whatever core
looked like on the day they were forked. They call core statics that later get
removed, and nothing flags it: the class loads, the plugin registers, and it only
fatals when that one form is built. `/product/add/custom` fataled on
`Datetime::formatExample()` — **removed in D11** — from a widget forked off
`TimestampDatetimeWidget` to add a "+30 days" default. Every smoke test passed;
the route just wasn't in any of them.

Find them by intent, not by symptom — grep for core classes called statically
from custom plugins, then diff each fork against the core original:

```bash
grep -rn 'use Drupal\\Core\\.*\\Element\\' web/modules/custom --include='*.php'
find web/core -name "$(basename FORKED_FILE)"   # then diff the two
```

Take core's own resolution rather than reimplementing the removed call: core
dropped the format example from that widget instead of replacing it, and its
current version also stopped clobbering the field's `#description`. Following
core fixed the fatal *and* restored the field's real help text, which the fork
had been overwriting with a format hint for years.

**Grep for the removed APIs directly** — it costs seconds and finds the same
class of bug in contrib you'd otherwise hit one form at a time:

```bash
grep -rn 'getImplementations(\|formatExample(\|::moduleHandler()->getImplementations' \
  web/modules/custom web/modules/community web/modules/contrib web/themes --include='*.php' --include='*.module'
```

`ModuleHandler::getImplementations()` (deprecated 9.4, removed 11) is the common
one; core's replacement is `invokeAllWith($hook, callable)`, and core's own
`EntityViewDisplayEditForm::thirdPartySettingsForm()` is the reference shape,
null-coalesce included. On one site this was a fatal in `exo_alchemist` on
`/block/add/<bundle>`.

**Half-declared entity relationships fatal only once something reads the other
half.** Core always pairs `bundle_entity_type` (on the content entity) with
`bundle_of` (on the bundle entity). A `hook_entity_type_alter()` that sets only
the first works fine until a module discovers the bundle entity by the forward
key and then reads the reverse — simple_sitemap does exactly this and throws
`Entity does not provide bundles for another entity type`. Fix the definition,
not the consumer:

```bash
grep -rn "set('bundle_entity_type'" web/modules/custom web/modules/community
```

---

## Phase 5 — jQuery 4

D11 ships **jQuery 4**, which removed long-deprecated APIs. Two distinct
problems:

### Removed utility functions

`$.isFunction`, `$.isArray`, `$.trim`, `$.isWindow`, `$.isNumeric`, `$.type`,
`$.parseJSON`, `$.now` and `.andSelf()` are gone. Unmaintained vendored
libraries still call them and throw, aborting their init — colorbox, select2 and
old jQuery UI plugins are common offenders. The visible symptom is "a display
looks slightly off", because a behaviour silently died.

**Check the list against the file, not against a blog post.** `.bind()`,
`.unbind()`, `.delegate()`, `.undelegate()` and the shorthand event methods
(`.click()`, `.focus()`, `.change()`…) are **still present** in the 4.0.0 Drupal
ships — deprecated, not removed. Treating them as breakage sends you rewriting
call sites for nothing:

```bash
grep -n "unbind:\|	trim:\|isFunction" web/core/assets/vendor/jquery/jquery.js
```

Catch the real ones by capturing console errors, not by reading source:

```js
page.on('pageerror', e => errors.push(e.message));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
```

For **vendored** libraries you do not own, shim (eXo does this for pickadate in
`exo_form/lib/pickadate/jquery4-shim.js`). For **your own** code, fix properly —
native `.trim()`, `Array.isArray`, `typeof x === 'function'`.

Find the offenders that are actually *on the page*, rather than every match in
`web/libraries` (most hits are bundled test copies of jQuery itself):

```bash
curl -sk "$URL" | grep -oE 'src="[^"]*\.js[^"]*"' | sed 's/src="//;s/"//;s/?.*//' \
  | grep '^/' | sort -u | sed 's|^|web|' | xargs grep -l "isFunction"
```

Attach the shim with `hook_library_info_alter()` so load order comes from the
dependency graph. **Key it by the extension that DECLARES the library, which is
often not the one the asset is named after** — `getLibraryByName()` returns
`FALSE` and the shim silently never attaches if you guess:

```php
$needs_shim = [
  'colorbox'    => ['colorbox'],
  'webform'     => ['libraries.jquery.select2'],   // not select2/select2
  'exo'         => ['jquery.ui.sortable'],
  'color_field' => ['color-field-widget-spectrum'],
];
```

Verify each one resolved, rather than assuming:

```bash
ddev drush php:eval '$d = \Drupal::service("library.discovery");
print var_export($d->getLibraryByName("webform", "libraries.jquery.select2"), TRUE);'
```

#### The trap: never put a `weight` on the shim

A shim library declaring `dependencies: [core/jquery]` is already guaranteed to
load after jQuery and before its consumer. Adding a weight to "make sure it goes
first" orders it **ahead of jQuery itself**, and since every such shim opens with

```js
if (typeof jQuery === 'undefined') { return; }
```

it becomes a silent no-op. Everything looks correctly wired — the file is on the
page, `getLibraryByName()` shows the dependency — and the original error keeps
throwing. Confirm the emitted order, don't infer it:

```bash
curl -sk "$URL" | grep -oE 'src="[^"]*(jquery4-shim|jquery\.min|colorbox)[^"]*"' | nl
```

### jquery.once is gone

`core/jquery.once` was removed in **Drupal 10**. Libraries still declaring it
have an unresolvable dependency, and `$(sel).once('id')` throws unless something
(eXo ships a copy) happens to provide it. Migrate to `core/once`:

```js
// before
$(context).find(sel).once('id').each(function () { … $(this) … });
// after
once('id', sel, context).forEach(function (el) { … $(el) … });
// or, to keep an existing jQuery chain intact with a minimal diff
$(once('id', sel, context)).each(function () { … $(this) … });
```

Expect this to be **partially done** already on older sites, which is why the
breakage looks patchy. Grep both the library declarations and the call sites.

Three shapes do not translate mechanically, and each fails differently:

- **jQuery-only selectors** (`:visible`, `:first`) are not valid CSS, so they
  cannot be the `selector` argument. Resolve the collection first and pass the
  elements: `once('id', $('.block.cart:visible'))`.
- **`$(window).once()` / `$(document).once()`** — `once()` marks elements via
  `setAttribute`, so a non-`Element` throws or silently returns nothing. Keep the
  handler on `window`/`document` and hang the guard off `body`:
  ```js
  if (once('my-id', 'body').length) { $(window).on('load resize', …); }
  ```
- **No-argument `.once()`** defaulted to the id `once`. Give it a real, unique id
  — reusing one id across two behaviours means the second never runs.

Note eXo bundles its own `lib/jquery.once/jquery.once.min.js`, so `.once()` may
keep working at runtime long after you have removed the core dependency. That
masks the problem locally; do not read "it still works" as "it is migrated".

Do not take a jQuery *removal* as part of the upgrade. Drupal still ships it,
contrib requires it, and the regression surface is exactly the pages you can
least afford to break. Fix the removed APIs; leave the rest.

### Rebuilding theme assets — two blockers before you can verify anything

None of the above is testable until the theme/module assets recompile, and on an
older site the build is usually broken before you start.

- **`ddev gulp ddev` can never work.** In the augustash gulpfile `exports.ddev`
  is the *host-side* task — it shells out to `ddev describe -j`. Run inside the
  container that returns "You executed a ddev command…", and the failure surfaces
  as `SyntaxError: Unexpected token 'Y', "You execut"... is not valid JSON`, which
  reads like a drush problem and is not. Use the default task in-container
  (`ddev gulp watch` is the normal flow). Note `ddev gulp` is hardcoded to the
  *theme's* gulpfile — a custom module with its own build needs `-f`.
- **`node-sass` cannot build on modern Node.** Python 3.12 dropped `distutils`,
  so `npm install` dies in `node-gyp`. It is almost always a stale entry: the
  gulpfile binds `gulp-sass` to dart-sass (`require('sass')`), so `node-sass` is
  unused. Drop it from `package.json` rather than pinning Node backwards.

Rebuilding also regenerates exo's CSS from the newly-installed exo, so expect a
handful of changed `css/*.css` files that have nothing to do with your edit.
Commit those separately — they are build output, not the fix.

### Prove the regression test actually fails

A console-error spec that only logs will pass forever. Assert on **uncaught
exceptions** (`pageerror`) — console `error` entries are full of third-party
noise you do not control — and then verify the test has teeth by reintroducing
the bug and watching it go red:

```js
expect(pageErrors, `uncaught exceptions on ${path}`).toEqual([]);
```

When triaging that noise, attribute each message to its source before assuming
it is yours. `m.location().url` groups them instantly, and on a marketing site
the overwhelming majority belong to analytics, A/B and personalisation vendors.

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
- [ ] **Every entity add/edit form opened, one per bundle** — not just the admin
      menu. Sweeping the client's whole admin menu (26 paths) came back clean
      while `/product/add/custom` fataled, because field widgets only execute on
      forms and no form is reachable from a menu. List pages prove nothing about
      widget code.
- [ ] Custom test suite green
- [ ] Checkout exercised — via the `manual` gateway in tests, and by hand for
      real gateways, which tests deliberately never touch

## Related memory

[[d11-symfony-runtime]] · [[cross-version-db-pull]] · [[phpunit-testing]] ·
[[exo-d11-image-formatters]] · [[config-split-ignore-collision]] ·
[[admin-theme-keyed-config]]

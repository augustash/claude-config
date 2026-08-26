---
name: site-update
description: Run a routine dependency-update pass on a client site — Drupal (composer) or WordPress. Covers the phase order that keeps the site bootable, patch triage and the composer-patches mechanics that make an edited patch silently not apply, which bumps to take and which to hold, and the verification that catches a break composer reported as success. Owns patch handling for every Drupal skill. Use for scheduled or ad-hoc maintenance rounds. NOT for a major core version increment — that's an upgrade, see drupal-11-upgrade — and not for adding a new dependency.
---

# Site update pass

Routine, but it fails in a specific way: **`composer update` is all-or-nothing on
patches.** One stale patch and *nothing* updates — and composer will have already
deleted the module's directory before it discovered the patch won't apply. The
site looks catastrophically broken over a one-line problem. Phase 2 is most of
this skill for that reason.

**Update vs upgrade.** An update moves dependencies inside a major core version —
contrib bumps, `11.4.4 → 11.4.5`, a module going `1.x → 2.x`. An upgrade moves
core's major (`10 → 11`) and is a different job with platform gates, a static
analysis pass and a multidev; it has [its own
skill](../drupal-11-upgrade/SKILL.md). An upgrade is a superset — it does
everything here **plus** those gates — so the patch handling in Phase 2 is the
same procedure in both, and lives here.

## The one rule

**A green exit code is not evidence the site works.** After the update, hit real
pages — including one authenticated form for anything whose *widget* changed.
`drush cr` and `drush updb` both succeed happily over a site that 500s on every
request; see
[d11-symfony-runtime](../../memory/drupal/d11-symfony-runtime.md) for a case
where `drush status` reported perfect health through a full anonymous WSOD.

---

## Phase 0 — Start from a clean, current base

Do not update on top of unknown local state. In order:

```bash
git status                 # anything uncommitted is yours to explain first
git pull --no-rebase       # merge, not rebase
ddev composer install      # match the lock you just pulled
ddev drush cr
ddev drush cim -y
```

`cim` before the update, not after — you want the site coherent *before* you
change dependencies, so anything that breaks next is attributable to the update.

**If the local DB was pulled from prod, the `cim` is not optional.** A pulled DB
carries prod's *installed module list*, so the dev split's modules are gone;
skip the import and a later `cex` silently blanks the whole `config-dev/` folder.
See
[config-split-export-wipes-folder](../../memory/drupal/config-split-export-wipes-folder.md).

**If `cim` itself dies, read the error text before assuming which one it is** —
three distinct failures look alike, all leave config half-applied, and two of
them are "fixed" by re-running, which teaches the wrong lesson:

- [cim-empty-config-object](../../memory/drupal/cim-empty-config-object.md) —
  names `checkOp()`, never clears on its own
- [config-split-db-push-mass-uninstall](../../memory/drupal/config-split-db-push-mass-uninstall.md)
  — no PHP error line, walks forward each run
- [config-split-ignore-collision](../../memory/drupal/config-split-ignore-collision.md)
  — "depends on the Y module that will not be installed"

Uncommitted `composer.lock` at the start usually means a previous session's
update ran and stopped. Read its diff before doing anything:
`git diff composer.lock | grep -E '^[-+] +"version"'`.

Ignore `.ddev/addon-metadata/*/manifest.yaml` churn — a `ddev restart` rewrites
`install_date`. It's noise, not a change.

---

## Phase 1 — `composer update -W`

```bash
ddev composer update -W 2>&1 | tail -60
```

Read the **tail**. Composer's failure message is buried under a usage dump and
repeated twice (once as stdout, once as stderr) when ddev wraps it.

If it aborts on a patch, go to Phase 2. Nothing was written; re-run after fixing.
"Nothing to modify in lock file" on a re-run means the version bumps already
landed on an earlier attempt and only the install/patch step was failing.

### Two traps that make an update quietly not happen

**A new `allow-plugins` prompt is a decision, not noise.** Answering "no" to
suppress it can be a WSOD. The standing example: crossing into core **11.4**
pulls in `symfony/runtime`, whose plugin generates `vendor/autoload_runtime.php`
— set it `false` and every web request fatals while drush stays healthy. See
[d11-symfony-runtime](../../memory/drupal/d11-symfony-runtime.md). This fires on
a *minor* bump, which is why it belongs here and not only in the upgrade skill.

**A dirty vendor tree makes a prefer-source package a silent no-op.** Our
internal packages (`augustash/claude-config` and friends) are installed as real
git checkouts, and composer's `VcsDownloader` refuses to touch one with
uncommitted changes — it aborts that package while the lock line still updates,
so it reads as success and the package's install hooks never run. If you have
been writing memory this session, that tree *is* dirty. Commit it first. See
[internal-package-distribution](../../memory/augustash/internal-package-distribution.md).

---

## Phase 2 — Patch triage

**This section is the canonical patch procedure for all our Drupal work** — an
upgrade hits the same wall and should come here rather than carry its own copy.

The failure looks like this:

```
Removing package drupal/paragraphs so that it can be re-installed and re-patched.
Deleting web/modules/contrib/paragraphs - deleted
  - Applying patches for drupal/paragraphs
   Could not apply patch! Skipping.
In Patches.php line 331:
  Cannot apply patch <name> (<path-or-url>)!
```

The module directory is now **gone**. That's expected and self-healing — a
successful re-run reinstalls it. Don't go restoring it by hand.

Fix one patch, re-run, hit the next one. Composer stops at the first failure, so
a site with four patches can need four rounds.

**Before hunting for a replacement patch, check
[patches.md](../../memory/drupal/patches.md)** — the cross-project index of ones
we've already vetted.

### A patch that fails to apply is asking whether it's still needed

Not "how do I fix the hunk". The failure means upstream edited exactly the code
the patch touched, which is the strongest signal you'll get that the situation
changed. A patch that *applies* cleanly means upstream left that code alone,
which is only weak evidence the bug survives.
[carried-fix-obsolete-check](../../memory/augustash/carried-fix-obsolete-check.md)
has the full argument, including the two outcomes from one sitting.

### Step 1 — Get the pristine source of the *new* version

Not the drupal.org issue page, not the old installed copy. **Compare against
upstream's current file, not its log** — upstream rarely describes a fix the way
we did, and may have removed the problem while refactoring something else, so "no
matching commit" reads as "still broken" when it can equally mean "solved,
differently".

```bash
ddev exec 'ls /mnt/ddev-global-cache/composer/files/drupal/<module>/'
ddev exec 'mkdir -p /tmp/x && cd /tmp/x && unzip -oq /mnt/ddev-global-cache/composer/files/drupal/<module>/<hash>.zip'
ddev exec 'grep -m1 version: /tmp/x/<module>/<module>.info.yml'   # which one is which
```

If the release isn't cached, `curl https://ftp.drupal.org/files/projects/<pkg>-<version>.tar.gz`.

### Step 2 — Is it merged?

Read the code the patch targets in that pristine copy and answer honestly:
**is the fix already there?**

Check the patch's *whole* footprint first — a "d11 compatibility" patch that
turns out to touch only `info.yml` is answered by one `curl`:

```bash
curl -s <patch-url> | grep -E '^(diff|---|\+\+\+)'
```

- **Merged** → delete the entry from `composer.json` → `extra.patches`, and
  delete the local `patches/*.patch` file if it was ours. Then chase the
  collateral:
  - An `extra.drupal-lenient.allowed-list` entry for that module exists
    *because* the module didn't declare the core version. If the new release
    declares it, that entry is dead too — and so is the
    `mglaman/composer-drupal-lenient` package once the list empties.
  - **A memory documenting that bug is now dead weight.** Upstream releasing
    the fix is exactly the deletion trigger in
    [memory-audit](../../memory/preferences/memory-audit.md). Grep the corpus
    for the module name and delete what's been fixed.
  - If it's listed in [patches.md](../../memory/drupal/patches.md), remove it
    there too — otherwise the index recommends a patch that no longer applies.
- **Not merged** → step 3. And if it's proven useful on a second project, that's
  the bar for *adding* it to `patches.md`.

### Step 3 — Not merged: did the code move?

This is the common one in the D11 era. Core's OOP hook conversion moved
procedural hooks out of `foo.module` and into `src/Hook/FooHooks.php`; the
`.module` function is now a one-line forward:

```php
#[LegacyHook]
function paragraphs_preprocess_field_multiple_value_form(&$variables) {
  \Drupal::service(ParagraphsHooks::class)->preprocessFieldMultipleValueForm($variables);
}
```

The patch didn't rot — its target relocated. Re-target it. Expect this on any
module that has recently done its D11 hook conversion, and expect the line
numbers *and* the indentation to have changed with it.

### Step 4 — Regenerate the patch

Diff pristine against edited. Do it against the **cached release**, never against
the installed (already-patched, possibly deleted) copy:

```bash
# in-container, since that's where the cache lives
SRC=/tmp/x/<module>
rm -rf /tmp/pw && mkdir -p /tmp/pw/a /tmp/pw/b
cp -r "$SRC/src" /tmp/pw/a/src
cp -r "$SRC/src" /tmp/pw/b/src
# ...edit /tmp/pw/b/... ...
cd /tmp/pw && diff -u a/src/Hook/FooHooks.php b/src/Hook/FooHooks.php \
  > /var/www/html/patches/<name>.patch
```

Then normalise the two header lines to `--- a/<path>` / `+++ b/<path>` — `diff`
appends timestamps, which work but read as machine spew in review.

**Keep one patch file per package**, regenerated wholesale (`diff -ruN a/ b/`)
rather than a set of hand-edited files. That is what makes Step 1 cheap next
time, and it is the prevention for the install-time trap below.

Mechanics that will bite:

- **`ddev exec` eats your variables.** The block above dies with
  `SRC: unbound variable` if you paste it into `ddev exec bash -c '...'`. Put it
  in a script file and run that — which is the right move here anyway, since the
  edit step wants a heredoc'd Python block that no amount of escaping survives.
  See [ddev-exec-var-expansion](../../memory/augustash/ddev-exec-var-expansion.md).
- **Mutagen lag, both directions.** `ddev mutagen sync` before the `ddev exec`
  (or the script file 127s as not found) *and* after it (or you `cat` the patch
  you just generated and see the old one, and conclude the write failed). See
  [ddev-mutagen-sync-lag](../../memory/preferences/ddev-mutagen-sync-lag.md).
- Patch paths are `-p1`, so they're relative to the package root
  (`src/Hook/Foo.php`), not the site root.

Re-indent the block you wrap rather than leaving the original indentation inside
a new `if`. Bigger diff, correct code — and the next person to re-target it can
read it.

### The patch you edited may never be applied

**composer-patches only applies patches at package INSTALL time.** If a package's
version and `dist.reference` are unchanged between the old and new lock, composer
does not reinstall it, so composer-patches never runs for it — and the package
keeps whatever patch output it already had, including content from before you
edited the file.

Locally this is masked: today's re-target worked only because paragraphs was
*also* being version-bumped, so it got reinstalled anyway. Edit a patch for a
package whose version doesn't move and nothing happens, silently.

On a Pantheon build (incremental, artifact reused) it is worse, because every
symptom misleads:

- The build succeeds. `composer-exit-on-patch-failure: true` never fires — no
  patch was *attempted*, so nothing failed.
- The corrected patch file **is** present in the build.
- Other patches look fine, but only because their content never changed, so
  cached-and-patched is indistinguishable from freshly-patched.
- Only the patch whose **content** you edited is stale.

Diagnose by checking patch *output*, not the patch file:

```bash
terminus drush SITE.ENV -- php:eval '
echo str_contains(file_get_contents("/code/web/modules/contrib/X/src/Y.php"), "NEW_SYMBOL")
  ? "patched" : "STALE";'
```

**Fixes that do NOT work** (all verified): editing the patch file; renaming it or
changing its description; `composer update <pkg>` ("Nothing to modify in lock
file"); committing `patches.lock.json`; upgrading to composer-patches **v2**
(same install-time-only behaviour, and it additionally failed to apply patches v1
applied fine — "No available patcher was able to apply" — taking the whole
install down).

**The fix that works — two pushes:** remove the package from `composer.json` +
lock, push, let the build uninstall it; then re-add and push, so the build
installs fresh and patches apply. One commit doing both is a no-op: re-adding
produces a byte-identical lock entry, so composer sees no change. *(Don't run
`drush deploy` in that window — the module's config is still enabled while its
code is gone. Config is safe as long as you never `pm:uninstall`.)*

Related: **`composer reinstall` is broken under composer-patches v1** — the
plugin removes all patched packages, then composer's reinstall fails with
"Package is not installed", leaving core and everything else deleted. Recovery is
`composer install`; prefer it over `reinstall` always. And **re-check every patch
after any composer thrashing** — packages reinstalled during unrelated operations
silently lose their patches. Verify by grepping for a known symbol from each
patch, not by trusting the log.

---

## Phase 3 — What to take

`composer update -W` only moves things inside their constraints. The real
decisions are the majors sitting outside them:

```bash
ddev composer outdated --direct
```

**Default is: take it.** Minors and majors both. A major bump is normal work,
not an event.

**Stability only ever goes up.** alpha → beta, beta → rc, anything → stable: fine,
take it. Stable → alpha/beta/rc: **no**, ever, even if it's a higher number.
(`rdf 3.0.0-beta2 → 4.0.0` is a textbook take — major *and* it lands on stable.)

**Hold — and say why in the reply, don't silently skip:**

- **Suite members.** A package versioned in lockstep with a family
  (`jacerider/escort` 4.x pairs with Aeon, 5.x with Neo). Bumping one member of a
  suite in isolation breaks it. Update the suite together or not at all.
- **Pinned by the upstream.** `tecnickcom/tcpdf` is `^6.7` in
  `pantheon-upstreams/drupal-project`. Widening the root constraint fights the
  upstream for no gain. Check `composer why <pkg>` before assuming a root require
  is really ours.
- **Genuinely scary integrations.** `salesforce` is the standing example — an
  external contract, not just code. Rare; name them explicitly rather than
  treating "major" as the criterion.
- **A tool whose reason has expired.** If a dev-tooling package's whole job is
  gone (see the `composer-drupal-lenient` note in Phase 2), the answer is
  *remove*, not *bump*.

**Bump risky majors on their own line.** Batch the boring ones; give anything
that rewrites config or field widgets its own `composer require` so its lock diff
is isolatable when something turns up two hours later.

```bash
ddev composer require -W 'drupal/a:^5.0' 'drupal/b:^4.0'   # the boring batch
ddev composer require -W 'drupal/geolocation:^4.0'         # the one to watch
```

---

## Phase 4 — Land it

```bash
ddev drush cr
ddev drush updbst          # read this before running it
ddev drush updb -y
ddev drush cr
ddev drush cex -y
ddev drush config:status   # want: "No differences"
```

Read `updbst` first — it's the only preview you get of what a major bump intends
to do to your data.

**A major with no update hooks is information, not relief.** Either it needed no
migration, or it expects you to fix config by hand. Confirm which by exercising
the feature (Phase 5), not by the absence of hooks.

**If you bumped a neo/jacerider module, run `ddev drush neo:build:install`.**
Those modules ship Claude skills inside the module, and `composer update`
refreshes the module's copy but never the project's live `.claude/skills/` — so
the bump silently leaves the old skill text running. The command also rewrites
`package.json`, `tsconfig.json`, `vite.config.ts` and `.ddev/config.yaml`, so
check `git status` on those four rather than assuming. See
[neo-skills-sync](../../memory/augustash/neo-skills-sync.md).

### Reading the `cex` diff

`cex` after `updb` captures what the update hooks changed — but it is not a
per-change surface. **The first export after any gap carries every unexported
change since the last one**, so sort the diff into *what the hooks I just watched
produced* vs *inherited drift from earlier sessions*, and decide that once, here,
before drawing any commit boundary.
[cex-before-commit](../../memory/preferences/cex-before-commit.md) is the rule
and Phase 6 is where it lands.

Two deletion patterns that look alarming and aren't:

- **A whole split folder blanked** (`D config-dev/*`) — Phase 0's missing `cim`,
  not a broken split. `git checkout -- config-dev/`, `cim`, re-export.
- **Config core no longer ships** — D11 dropped `field.settings` outright, so
  `D config/field.settings.yml` is correct and came from `updatedb`. Check
  whether core still ships the item before restoring it. Both in
  [config-split-export-wipes-folder](../../memory/drupal/config-split-export-wipes-folder.md).

---

## Phase 5 — Verify

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://<site>.ddev.site/
curl -sk https://<site>.ddev.site/ | grep -oiE "the website encountered|TypeError|Fatal error"
ddev drush ws --count=25 --severity=Error
ddev drush core:requirements --severity=1
```

Then **exercise what you actually changed**. Find where the updated module is
used and hit it:

```bash
grep -rl '<module>' config/          # views, field storage, form/view displays
```

Anonymous coverage isn't enough — a field-widget change only shows on the edit
form, which is a 403 to anonymous. Log in and curl:

```bash
J=$(mktemp)
URL=$(ddev drush uli --uri=https://<site>.ddev.site | tr -d '\r')
curl -sk -c "$J" -b "$J" -L -o /dev/null "$URL"
curl -sk -c "$J" -b "$J" -o /tmp/o.html -w '%{http_code}\n' "https://<site>.ddev.site/node/<id>/edit"
grep -oiE "the website encountered|TypeError|ArgumentCountError" /tmp/o.html
```

### When a core *minor* bump breaks something

Core minors move typed signatures and default behaviour, and the fallout lands in
contrib and in our own modules. If something is off after core moved, check these
before debugging from scratch — each is a known shape, and two of them look fine
in a browser:

- [exo-d11-image-formatters](../../memory/drupal/exo-d11-image-formatters.md) —
  **11.4** added an 11th `ImageFormatter` constructor arg; any image field or eXo
  Gallery WSODs with `ArgumentCountError` or `TypeError` on arg #11
- [neo-image-avif-on-d11-2](../../memory/augustash/neo-image-avif-on-d11-2.md) —
  **11.2** switched Neo derivatives to AVIF; every page looks perfect and every
  link preview is broken
- [d11-symfony-runtime](../../memory/drupal/d11-symfony-runtime.md) — **11.4**,
  covered in Phase 1, included here because this is where you'd notice it

The general shape is a parent class gaining a constructor arg or a property type,
which is invisible to static analysis and fatal at render. Grep our custom and
augustash modules for `__construct` overrides that call `parent::__construct()`
with a positional list whenever core's minor moves.

### Don't inherit someone else's warning

`core:requirements` will surface things the update didn't cause. Before reporting
one as a regression, prove it: `git diff config/<the-config>.yml`. Unchanged
means it was already like that. (A missing Google Maps API key looks alarming
right after a geolocation major bump and has nothing to do with it.)

---

## Phase 6 — Commit

One idea per commit — and an update pass is more than one idea:

- **The dependency update** — `composer.json` + `composer.lock` + the config the
  update hooks produced, plus any patch re-target the bump forced. That's one
  revertible unit: the patch change exists *because* the version moved.
- **Inherited config drift** — its own commit, never a rider. It reverts cleanly
  that way and bundled it doesn't. ⚠ Pruning it from the export doesn't fix the
  *active* config, and the next `cex` re-exports it — say which you did. See
  [cex-before-commit](../../memory/preferences/cex-before-commit.md).
- **Refreshed neo skills** — alongside the module bump that moved them.
- **Cleanup the update exposed** — a now-pointless lenient entry, an abandoned
  package, a warning next to the work. Separate, always; it isn't part of
  "update dependencies", and it's expected rather than optional. See
  [proactive-cleanup](../../memory/preferences/proactive-cleanup.md).

Say in the message what moved and, if a major landed, what you verified.

Follow [commit-handoff](../../memory/preferences/commit-handoff.md) for whether
you push — on a Pantheon project the push is a deploy, so it stays the dev's.

---

## WordPress

Same spine, different tools. This lane is thinner than the Drupal one — extend it
as rounds get run.

```bash
ddev wp core check-update
ddev wp plugin list --update=available
ddev wp theme list --update=available
ddev wp core update && ddev wp plugin update --all && ddev wp theme update --all
ddev wp core update-db
```

Same take/hold rules. The stack-specific traps:

- **Reconcile live plugin drift before deploying.** WP Engine sites get plugins
  updated *in the dashboard*; a git deploy silently reverts them. See
  [wpengine-git-deploy](../../memory/wordpress/wpengine-git-deploy.md).
- **`ddev-wordpress` rewrites `wp-config.php` and `.gitignore`** on every
  `composer update` — check that diff, it isn't yours. See
  [ddev-wordpress-wpengine-gate](../../memory/augustash/ddev-wordpress-wpengine-gate.md).
- **Object Cache Pro serves pre-clone options** after a DB pull, so post-update
  settings checks can lie. See
  [object-cache-survives-db-clone](../../memory/wordpress/object-cache-survives-db-clone.md).
- **`terminus wp` can exit 0 printing nothing.** Never take silence as success on
  Pantheon. See
  [wp-cli-silent-on-pantheon](../../memory/wordpress/wp-cli-silent-on-pantheon.md).
- **A plugin that generates a file into the web root** bakes in whatever URL it
  was generated under — a local run ships `.ddev.site` URLs to production. See
  [aioseo-llms-txt-static-file](../../memory/wordpress/aioseo-llms-txt-static-file.md).

---

## Deploying

Pantheon's code log reports a deploy against the **previous** build for a short
window after a push, so a post-deploy check straight after can pass on the old
code. See
[pantheon-build-lag](../../memory/drupal/pantheon-build-lag.md), and confirm
before any `terminus` against `.live`/`.test`
([confirm-before-live-terminus](../../memory/preferences/confirm-before-live-terminus.md)).

---

## Reporting back

Lead with the decisions, not the transcript. What went up, what you held and why,
what you verified, what's left. The held list is the part worth reading — it's
the only place judgment was exercised.

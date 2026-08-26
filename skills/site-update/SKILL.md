---
name: site-update
description: Run a routine dependency-update pass on a client site — Drupal (composer) or WordPress. Starts at the Pantheon upstream — Drupal, Drupal 7 and WordPress each have one, and no package manager will bring it. Covers the phase order that keeps the site bootable, patch triage and the composer-patches mechanics that make an edited patch silently not apply, which bumps to take and which to hold, what to do when a licence or marketplace paygate blocks one, and the verification that catches a break the tooling reported as success. On WordPress it covers the WooCommerce round. Owns patch handling for every Drupal skill. Also use after upgrading ddev itself, to re-assert the project scaffolding. Use for scheduled or ad-hoc maintenance rounds. NOT for a major core version increment — that's an upgrade, see drupal-11-upgrade — and not for adding a new dependency.
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

Two files are churn, not change: `.ddev/addon-metadata/*/manifest.yaml` (a
`ddev restart` rewrites `install_date`) and `vendor/composer/installed.php`,
whose root-package `reference` records the project's own git HEAD, so it moves
every time you commit. Leave both out of the update commits.

### Check the Pantheon upstream first

On Pantheon, part of the site isn't ours: core (and on Drupal the composer
scaffolding around it) arrives from an upstream repo, and `composer update` /
`wp plugin update` will never bring it. Check it at the top of every round,
before the dependency work, since applying it can move `composer.json` itself:

```bash
ddev exec 'terminus upstream:updates:status <site>.dev'   # current | outdated
ddev exec 'terminus upstream:updates:list <site>.dev'     # what is pending, and why
```

Three upstreams, one per stack:

| Site | Upstream |
|---|---|
| Drupal (composer-managed) | `https://github.com/pantheon-upstreams/drupal-composer-managed` |
| Drupal 7 | `https://github.com/pantheon-systems/drops-7` |
| WordPress | `https://github.com/pantheon-systems/wordpress` |

`pantheon-upstreams/drupal-project` is **not** the composer-managed one under an
old name — it's a separate repo that still exists, and the platform labels it
*"Drupal 9 (deprecated)"*. `composer.json`'s own `name` field carries whichever
one the site was created from, and `terminus site:info <site>` gives the
authoritative answer in its `upstream:` line. If any of these URLs stops
resolving, [docs.pantheon.io/core-updates](https://docs.pantheon.io/core-updates)
is the authority; take the link from there rather than guessing a rename.

Nothing configures these as a git remote, so fetch the URL directly — and **ask
for the branch name rather than assuming `master`**; `drupal-composer-managed`
is on `main`, and a wrong guess fails as `couldn't find remote ref`, which reads
like the repo moved:

```bash
git ls-remote --heads https://github.com/pantheon-upstreams/drupal-composer-managed
git fetch https://github.com/pantheon-upstreams/drupal-composer-managed main
git log --oneline HEAD..FETCH_HEAD      # read it before merging
git merge FETCH_HEAD --no-edit
```

### When the upstream track is simply dead

On an older site all three signals can fail at once, and together they mean *skip
this step*, not *debug it*:

- `terminus upstream:updates:status` exits 1 with a bare
  `The operation failed to complete.` — auth is fine, the deprecated upstream
  just can't be diffed.
- `git merge-base HEAD FETCH_HEAD` prints **nothing**. The site's history was
  squashed or re-inited at some point, so it shares no ancestor with any
  upstream and `HEAD..FETCH_HEAD` lists the upstream's *entire* history back to
  `first commit` — 28 pending commits that are not pending at all.
- Diffing the scaffolding shows our `pantheon.upstream.yml` is the older
  `drupal-project` file (`php_version: 7.4`, no `web_docroot`, no `build_step`)
  and `upstream-configuration/` doesn't exist.

Before writing it up as exposure, read `pantheon.yml`: on a site like this the
platform settings the newer upstream would deliver (`php_version`,
`web_docroot`, `build_step`, `drush_version`) are usually already set there by
hand, so nothing is actually behind. Report it as a standing item — the site is
pinned to a deprecated upstream and only a re-point to
`drupal-composer-managed` clears it — and get on with the dependency round.

`terminus upstream:updates:apply <site>.<env>` does the same merge on the
platform instead, leaving you to `git pull` it back — worth knowing, but the
local merge is the one to prefer: you see the conflicts on your own machine,
with the site running, instead of discovering them in the dashboard.

**An upstream carries more than core.** Pantheon's MU plugin ships inside the
WordPress one, and the Drupal upstreams carry `upstream-configuration`,
`pantheon.yml` and scaffolding — so "two commits pending" is often one release
plus one platform change. Read the list, don't assume.

The merge commit *is* the core commit; there is nothing to stage afterwards.
Then bring the database up: `ddev wp core update-db`, or `ddev drush updb -y` as
part of Phase 4.

### When ddev itself was updated

A ddev upgrade moves the *binary*; it never touches the project's scaffolding.
Re-assert it:

```bash
ddev composer ddev-setup update    # no prompts, refresh in place
ddev restart                       # only if it says to
```

`ddev-setup` is the composer script our `augustash/ddev-drupal` /
`augustash/ddev-wordpress` package wires in. **Bare, it reconfigures**
interactively (every prompt seeded from the current value, so enter keeps it).
The `update` argument is the one you want here: keep the configuration, rebuild
everything generated from it — asset `config.yaml` keys the package has added
since, the `post-start` add-on hooks (`ddev add-on get
augustash/ddev-pantheon-db` + `ddev db`), the legacy `PANTHEON_SITE` →
`DDEV_PANTHEON_SITE` env rename, the terminus 3 downgrade Dockerfile for
PHP < 8.2, `settings.local.php` / `wp-config-local.php`, the WP Engine deploy
hooks, `.gitignore` appends, the browsersync compose file.

It ends with either *"Scaffolding refreshed — run `ddev restart`"* or
*"Everything up-to-date."* — decided by hashing the managed files before and
after, so a no-op says so instead of sending you into a pointless restart.

**Why a ddev bump specifically.** The scaffolding encodes things ddev owns and
moves between releases: its CLI surface (`ddev get` became `ddev add-on get`),
the config defaults it prunes against (that allowlist is validated against one
ddev version and rots), the add-on it re-fetches on every start. The hooks that
would refresh this on their own fire on `composer install` / `composer update`
**inside the web container only** — and on a project whose composer manages
nothing but dev tooling (most WordPress ones), months pass without either. Run
it by hand after the upgrade; it costs nothing when nothing moved.

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

### When you can't take it — paygates and dead ends

Some updates aren't a judgement call, they're a wall: a lapsed licence, an
expired marketplace subscription, a vendor who now sells the thing as a
different product, a version the platform pins. It surfaces as a *failed*
update with a renewal link, not as an absent one:

```
Warning: Please visit the subscriptions page and renew to continue receiving updates.
name                           old_version  new_version  status
woocommerce-tax-exempt-plugin  1.8.1        1.9.5        Error
```

**A wall is a deliverable, not a dead end.** Nobody on our side can renew the
client's WooCommerce.com subscription or their ACF licence, so the round ends
with a short client-facing page: what is stuck, what unsticking it costs, what
the exposure is meanwhile. Load the [client-report](../client-report/SKILL.md)
skill for it, and write a self-contained HTML file rather than an artifact — see
[deliverables-as-html-files](../../memory/preferences/deliverables-as-html-files.md).

Per blocked item, the page needs:

- The plugin, the version installed, the version it can't reach. **The gap is
  the argument** — "1.8.1 → 1.9.5, seven releases" lands where "out of date"
  doesn't.
- **A link they can act on, and whose account it is.** Check before writing
  "renew your subscription": these accounts are often the client's own, from
  before we took the site on, under a staff email that may have left. The Woo
  helper record carries the account name and the URL it was authorised
  against — read it, don't guess who owns it.
- What holding it costs: security fixes in the releases being skipped, and any
  compatibility ceiling now behind the site. A `WC tested up to: 8.*.*` header
  against WooCommerce 11 is concrete and non-technical readers get it.
- **What we did instead** — held at the working version, verified the site still
  runs on it. Say it plainly, or the item reads as "broken".

**Sweep the expiries you can see, not just the one that failed.** The same
subscription list that explains today's failure names what lapses next month;
one renewal conversation covering both beats two. On atr the blocked extension
had no subscription at all, while a live one had 11 days left — the second item
was the more useful half of the report.

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

Same spine, different tools — and on Pantheon a different core mechanism
entirely. Worked through on a WooCommerce/Pantheon round (atr, 2026-08-26);
extend it as more get run.

### Core comes from the upstream, not `wp core update`

The mechanics are in Phase 0 — check the upstream, fetch
`https://github.com/pantheon-systems/wordpress`, merge. What's WordPress-specific:

**`wp core update` is the wrong tool on Pantheon**, tempting as it looks. It
writes core files yourself and hands you a conflict against every future
upstream merge, on a directory tree you don't own.

**`git diff HEAD FETCH_HEAD` will lie to you.** The upstream tree has no
`wp-content/plugins`, so a full-tree diff reports every plugin we have as a
deletion — 27,787 files and 4.9M deletions on this round, which reads as
catastrophe. Diff the merge base:

```bash
git diff --stat $(git merge-base HEAD FETCH_HEAD) FETCH_HEAD | tail -5
```

That showed the real change: 1,487 files, one core release.

Then `ddev wp core update-db`. Answering *"already at latest db version"* is a
normal result, not a skipped step — not every release moves `db_version`.

### Plugins and themes

```bash
ddev wp plugin list --update=available
ddev wp theme list --update=available
ddev wp plugin update <a> <b> <c>       # the boring batch
ddev wp plugin update <the-one-to-watch> # its own run
ddev wp theme update --all
```

Same take/hold rules as Phase 3, same reason to split the batch: a plugin that
owns data or checkout gets its own run so its file diff is isolatable later.
Premium plugins update through their own licence servers, so a round can come
back partly blocked — that's *When you can't take it* above.

For WooCommerce marketplace extensions the subscription list is readable, and it
is the fastest answer to both "why did that fail" and "what lapses next":

```bash
ddev wp eval 'foreach (WC_Helper::get_subscriptions() as $s)
  printf("%s | expires %s | expired:%s\n", $s["product_name"],
    date("Y-m-d", $s["expires"]), !empty($s["expired"]) ? "yes" : "no");'
```

An extension that failed to update simply won't appear in it. ⚠ Read it that
way rather than through `wp option get woocommerce_helper_data` — that option
holds the account's OAuth access token and secret, and it must not land in a
report, a commit or a paste.

### A guard we carry is a patch by another name

An mu-plugin written to work around a contrib bug is exactly the carried fix
Phase 2 talks about, and a version bump is when to re-check it. Read the new
release's code, not its changelog:
[carried-fix-obsolete-check](../../memory/augustash/carried-fix-obsolete-check.md).
On this round AIOSEO Pro went 5.0.0.1 → 5.0.1 with
[the REST-head null](../../memory/wordpress/aioseo-rest-head-null-ajax-cron.md)
still unfixed at both ends, so the guard stayed and its "verified against"
note moved forward — cheap, and it stops the next round re-deriving it.

### Verifying a WooCommerce round

Most of the surface here is public, so anonymous coverage does real work: home,
`/shop/`, a product, `/cart/`, `/my-account/`, and a page carrying a form. A
`302` on `/checkout/` with an empty cart is a pass. Then the two checks a page
load won't give you:

```bash
curl -sk -o /dev/null -w '%{http_code}\n' 'https://<site>.ddev.site/wp-cron.php?doing_wp_cron'
ddev logs | grep -iE 'PHP Fatal|Uncaught'
```

wp-cron over HTTP is the only cheap way to exercise the `DOING_CRON` path, where
a whole class of plugin fatals lives (that AIOSEO one among them) and where
wp-cli's own context can't reach.

**Do not trigger a webhook to test one.** A local WooCommerce still holds the
client's real delivery URLs; firing `product.updated` to see whether the payload
builds sends live-shaped data to their Klaviyo or ERP from your laptop. Verify
the code path, not the delivery.

Two local-only alarms that are not findings — filter them out rather than
reporting them:

- **"Object Cache Pro is temporarily disabled — this is extremely risky"**, on
  every single wp-cli command. `wp-config.php` defines `WP_REDIS_DISABLED`
  off-Pantheon; that is the intended local configuration. (Post-update settings
  checks *can* lie for a real reason though — see
  [object-cache-survives-db-clone](../../memory/wordpress/object-cache-survives-db-clone.md).)
- **`/wp-login.php` 404s** wherever `wps-hide-login` is active.

### The stack-specific traps

- **Reconcile live plugin drift before deploying.** WP Engine sites get plugins
  updated *in the dashboard*; a git deploy silently reverts them. See
  [wpengine-git-deploy](../../memory/augustash/wpengine-git-deploy.md).
- **`ddev-wordpress` rewrites `wp-config.php` and `.gitignore`** on every
  `composer update` — check that diff, it isn't yours. See
  [ddev-wordpress-wpengine-gate](../../memory/augustash/ddev-wordpress-wpengine-gate.md).
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

### Every round ends with a client record

Not just the blocked ones. The [client-report](../client-report/SKILL.md) page
written for atr existed because the client had to *act* on a lapsed
subscription — but the standing habit is one short record per round regardless,
so "what did you do to our site last month" has a file to point at.

`docs/updates/<YYYY-MM-DD>-maintenance.html`, committed with the round. Borrow
that skill's §6 design rules and §7 integrity check; **ignore its ten-section
pitch structure** — this is a much smaller genre:

1. **Title block** — project, sheet, date, round, prepared by, and whether any
   action is required. Answer that last one in the header, not on page two.
2. **Updated** — a version table of the ten or so components a non-developer
   recognises, each with a plain-language gloss (*Webform — contact and request
   forms*). One caption line absorbs the rest: *"plus 36 supporting libraries."*
3. **Held back on purpose** — the section that earns the document. Every item
   gets its reason in the client's terms. Without it, a short list of versions
   reads as the whole job.

   **A hold the client cannot perceive does not belong here.** Build tooling,
   composer plugins, anything whose entire existence is upstream of their site —
   cut it, however real the decision was. On wps *"three build tools … one
   carries a fault that breaks deployments"* was struck for exactly this: it
   describes our machinery, and the reader has no way to care. What survived
   each mapped to something on their site, and the section got sharper for it.
4. **Checked afterwards** — the Phase 5 list, in their vocabulary. *Careers
   listing and its job search filters*, not *`/careers` returned 200*.
5. **Next** — only when there is something. Cut it otherwise rather than padding.

Pull the palette from the **theme's own variables file**, not the logo and not
memory, and inline the logo as an SVG with `fill="currentColor"` so the mark and
the document's brand colour cannot drift apart. On wps the theme's red was
`#e1251b` while `logo.svg` carried `#E02726` — near-identical, and visibly wrong
side by side.

### State where the platform sits in its support window — looked up, not recalled

The one claim in a maintenance record that is worth a client's attention is how
much runway the current major has, and it is exactly the claim most likely to be
written from memory and be wrong. On wps the draft said *"Drupal 10 is supported
into 2027, so there is room to plan"*; the schedule says **Drupal 10 reaches end
of life 9 December 2026**, and `10.6.x` is the final minor — about fifteen weeks
out, and the round had just taken core as far as Drupal 10 goes.

That single fact inverted the document. "Nothing needed from you" became a dated
upgrade window, and it belongs in the header cell rather than a closing
paragraph.

Check it every round, from the authority, at the moment you write it:

| Stack | Authority |
|---|---|
| Drupal | [drupal.org core release schedule](https://www.drupal.org/about/core/policies/core-release-cycles/schedule) |
| WordPress | [wordpress.org/about/roadmap](https://wordpress.org/about/roadmap/) — and the PHP version's own EOL, which bites first more often |

It also reframes Phase 3's hold list. Holding a module because its 4.x targets
the next major is correct *and* it is a countdown: each one is work that lands
with the upgrade. Say so in the internal report — a hold list that quietly
becomes an upgrade scope is worth surfacing before the client asks.

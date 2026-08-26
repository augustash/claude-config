---
name: site-update
description: Run a routine dependency-update pass on a client site — Drupal (composer), WordPress, or any stack we maintain. Covers the phase order that keeps the site bootable, the patch triage that a `composer update` failure forces on you (merged upstream? file moved? re-target), which bumps to take and which to hold, and the verification that catches a break composer reported as success. Use for scheduled/ad-hoc maintenance rounds. NOT for a major-platform migration (D10→D11 has its own skill), and not for adding a new dependency.
---

# Site update pass

Routine, but it fails in a specific way: **`composer update` is all-or-nothing on
patches.** One stale patch and *nothing* updates — and composer will have already
deleted the module's directory before it discovered the patch won't apply. The
site looks catastrophically broken over a one-line problem. Most of this skill is
the triage for that.

## The one rule

**A green exit code is not evidence the site works.** After the update, hit real
pages — including one authenticated form for anything whose *widget* changed.
`drush cr` and `drush updb` both succeed happily over a site that 500s on every
request.

---

## Phase 0 — Start from a clean, current base

Do not update on top of unknown local state. In order:

```bash
git status                 # anything uncommitted is yours to explain first
git pull --no-rebase       # merge, not rebase
ddev composer install      # match the lock you just pulled
ddev drush cr
ddev drush cim -y          # or `config:status` first if you want to see it
```

`cim` before the update, not after — you want the site coherent *before* you
change dependencies, so anything that breaks next is attributable to the update.

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

---

## Phase 2 — Patch triage

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

### Step 1 — Get the pristine source of the *new* version

Not the drupal.org issue page, not the old installed copy. The actual release:

```bash
ddev exec 'ls /mnt/ddev-global-cache/composer/files/drupal/<module>/'
ddev exec 'mkdir -p /tmp/x && cd /tmp/x && unzip -oq /mnt/ddev-global-cache/composer/files/drupal/<module>/<hash>.zip'
ddev exec 'grep -m1 version: /tmp/x/<module>/<module>.info.yml'   # which one is which
```

### Step 2 — Is it merged?

Read the code the patch targets in that pristine copy and answer honestly:
**is the fix already there?**

Also check the patch's *whole* footprint first — a "d11 compatibility" patch that
turns out to touch only `info.yml` is answered by one `cat`:

```bash
curl -s <patch-url> | grep -E '^(diff|---|\+\+\+)'
```

- **Merged** → delete the entry from `composer.json` → `extra.patches`, and
  delete the local `patches/*.patch` file if it was ours. Then check for
  collateral: an `extra.drupal-lenient.allowed-list` entry for that module
  exists *because* the module didn't declare the core version — if the new
  release declares it, that entry is dead too. So is the
  `mglaman/composer-drupal-lenient` package itself once the list empties.
- **Not merged** → step 3.

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

The patch didn't rot — its target relocated. Re-target it.

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

Mechanics that will bite:

- **`ddev exec` runs with `set -u`.** A multi-line `bash -c '...'` that sets a
  variable dies with `SRC: unbound variable`. Write the script to a file in the
  project (mounted at `/var/www/html`) and `ddev exec bash /var/www/html/x.sh`.
  Same for anything with nested quoting — a heredoc'd Python script inside a
  single-quoted `bash -c` is unwinnable.
- **Mutagen lag.** A file written inside the container reads *stale* on the host.
  You will `cat` the patch you just generated and see the old one, and conclude
  the write failed. Run `ddev mutagen sync` first. See
  [ddev-mutagen-sync-lag](../../memory/preferences/ddev-mutagen-sync-lag.md).
- Patch paths are `-p1`, so they're relative to the package root
  (`src/Hook/Foo.php`), not the site root.

Re-indent the block you wrap rather than leaving the original indentation inside
a new `if`. Bigger diff, correct code — and the next person to re-target it can
read it.

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

`cex` after `updb` captures what the update hooks changed. Everything it exports
should be traceable to a hook you just watched run — if a config file you don't
recognise shows up, it's another session's work riding along; see
[cex-before-commit](../../memory/preferences/cex-before-commit.md).

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

### Don't inherit someone else's warning

`core:requirements` will surface things the update didn't cause. Before reporting
one as a regression, prove it: `git diff config/<the-config>.yml`. Unchanged
means it was already like that. (A missing Google Maps API key looks alarming
right after a geolocation major bump and has nothing to do with it.)

---

## Phase 6 — Commit

One idea per commit — and an update pass is more than one idea:

- **The dependency update** — `composer.json` + `composer.lock` + the config the
  update hooks produced. That's one revertible unit.
- **A patch re-target or removal** — its own commit if it's substantive; folded
  into the update commit if it's a one-line entry deletion.
- **Cleanup the update exposed** (a now-pointless lenient entry, an abandoned
  package) — separate, always. It isn't part of "update dependencies."

Say in the message what moved and, if a major landed, what you verified.

Follow [commit-handoff](../../memory/preferences/commit-handoff.md) for whether
you push.

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

---

## Reporting back

Lead with the decisions, not the transcript. What went up, what you held and why,
what you verified, what's left. The held list is the part worth reading — it's
the only place judgment was exercised.

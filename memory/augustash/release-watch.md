---
name: release-watch
description: The weekday-morning check for published security advisories reaching a client site, its red status-line alert, and installing it
metadata:
  type: reference
---

# Release watch: hear about critical releases before the client does

Clients were telling us about critical releases. [templates/release-watch/](../../templates/release-watch/)
checks every client clone each weekday morning and raises the alarm first (Kaza, 2026-11-03).
Its first run found 16 sites on a core with that month's critical RCE, two of them on
Drupal 9 with seven criticals open.

## Install it on your machine

```bash
bash vendor/augustash/claude-config/templates/release-watch/install.sh        # weekdays 07:30
bash vendor/augustash/claude-config/templates/release-watch/install.sh 08:15  # another time
```

Then add the two lines it prints to your Claude Code status line script. A Mac asleep at
7:30 runs the check when it wakes. Day to day:

```bash
python3 …/release-watch.py show              # the digest: every open advisory, ranked
python3 …/release-watch.py ack SA-CORE-2026-014   # silence one in the status line ("all" works)
```

An advisory clears itself once no client's committed lock is affected, i.e. after the deploys.

## What it decides, and why

- **Red** is Drupal's *Critical* and *Highly critical* ratings (read from the advisory title,
  the only place Drupal states it) and any advisory with a `critical` severity, which is
  CVSS 9 and up. Everything lower goes in the digest only, so the red still means "today".
  Kaza's threshold, open to adjustment.
- **It reads `origin/master` after a fetch**, not the working copy: that's what Pantheon
  deploys, and `origin/HEAD` is often stale (kow's points at a `main` untouched since 2023).
- **A contrib module that's installed but not enabled is listed, never red.** Dev-only
  modules (Stage File Proxy) live in a config split, so they show in the lock but don't run
  on live. Enabled-ness comes from `core.extension.yml` at the same ref.
- **"Affects most"** ranks clients by: runs the code, is a store, is on POM+ (the roster in
  [pom/levels](../pom/levels.md)). The status line names the first, plus a count.
- **Matching is `composer audit --locked`** on each committed lock, not our own version
  parsing. Two traps: the host's Composer may predate 2.6, which lacks `--abandoned` and
  fails the whole audit on it; and our private Packagist needs a token the host lacks, so the
  script drops that repository (it hosts no advisories) and keeps every other.
- **A site it can't audit is reported as a failure, never counted as clean.** The first draft
  said "4 sites checked, 0 advisories" while every audit had failed.

## Known gaps

- `origin` is each site's Pantheon repo, so `origin/master` is **dev**'s code. Live is the
  same or older: a fix on master that was never deployed reads as clear while live is still
  exposed. Closing that needs each site's live commit from `terminus env:code-log`.
- WordPress plugins not managed by composer don't appear. Covering them needs a
  `terminus wp plugin list` pass per site.
- WordPress advisories don't say whether a flaw needs a login, so "unauthenticated CVSS 9+"
  is approximated as CVSS 9+.
- Clients are identified by their `~/Projects` folder name; clones idle over a year are
  skipped and listed in the digest (`max_idle_days` and `ignore` in
  `~/.config/release-watch/config.json`).

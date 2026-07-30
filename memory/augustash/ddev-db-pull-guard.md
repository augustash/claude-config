---
name: ddev-db-pull-guard
description: The `ddev db` post-start hook is idempotent — it refuses to pull when a database is already present, so `ddev restart` never clobbers a local DB and `--skip-hooks` is not needed to protect one.
metadata:
  type: reference
---

`augustash/ddev-pantheon-db` wires `ddev db` into `post-start` in `.ddev/config.yaml`:

```yaml
hooks:
    post-start:
        - exec-host: ddev add-on get augustash/ddev-pantheon-db --version develop
        - exec-host: ddev db
        - exec-host: ddev solrcollection
```

Read cold, that looks like every `ddev start` re-pulls the Pantheon database over your local
one — which makes restarting a project feel destructive, especially on a site mid-upgrade whose
local DB carries `updatedb`, config imports and a Solr reindex that the remote does not.

**It doesn't.** `commands/host/db` guards first:

```bash
TABLE_COUNT=$(echo "SHOW TABLES;" | ddev mysql --skip-column-names 2>/dev/null | wc -l | tr -d ' ')
if [[ $TABLE_COUNT -gt 1 && $FORCE != true ]]; then
  exit 0
fi
```

A database with more than one table and no `-f` means the hook exits immediately. It also
suppresses its "already installed" notice when there's no TTY, precisely so the post-start
invocation stays silent — which is why the hook leaves no trace suggesting it ran and declined.

Two further safeties: with `DDEV_PANTHEON_ENVIRONMENT` unset it refuses rather than defaulting
to an environment (no accidental production pull into a fresh local), and the threshold is
`> 1` rather than `> 0`, so a stale shell of a database still gets seeded properly.

**How to apply:** Don't avoid `ddev restart` / `ddev start` to protect a local database, and
don't reach for `--skip-hooks` on those grounds — the guard already covers it. Note this cuts
both ways: because a populated DB is skipped, a plain restart will *not* refresh stale data.
Pull deliberately with `ddev db -f`, adding `-e=<env>` to target a specific environment. Be
aware a pull that does run is not data-only — on Drupal projects it finishes with
`ddev composer install && ddev drush deploy -y`.

Related: [[ddev-drupal-pantheon-site-var]], [[internal-package-distribution]]

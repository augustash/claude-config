---
name: Cross-version DB pull — run drush deploy, never cr/cim before updatedb
description: Pulling an older-Drupal prod DB into newer local code and rebuilding (cr/cim) before updatedb faceplants on "Unknown column 'alias' in router" — D11.1's system_update_11201 adds {router}.alias, absent in the pulled schema. Correct order is drush deploy (updatedb → config:import → cache:rebuild → deploy:hook). augustash ddev-pantheon-db ≥1.0.5 does this.
type: reference
---

# Cross-version DB pull — run drush deploy, never cr/cim before updatedb

During a major-version upgrade the working branch/local runs newer core (e.g. D11.4) while prod is still on the old version (e.g. D10). Pull prod's database down, then run a cache/route rebuild **before** `updatedb` and it dies:

```
SQLSTATE[42S22]: Column not found: 1054 Unknown column 'alias' in 'INSERT INTO':
  INSERT INTO "router" ("name", "route", "alias") ...
  in Drupal\Core\Routing\MatcherDumper->dump()
```

**Why:** Drupal **11.1** added the `{router}.alias` column, installed by `system_update_11201`. The pulled (D10) schema doesn't have it; `drush cr` rebuilds the router and inserts into the new column → fails. `{router}` is a derived table, but core does **not** recreate it with the new schema on rebuild — the update hook is what adds the column. So the schema must be migrated first.

**Fix / correct order:** `updatedb` **first** (migrates schema, adds the column), then `config:import`, then `cache:rebuild` — i.e. just run **`drush deploy`** (`updatedb --no-cache-clear` → `config:import` → `cache:rebuild` → `deploy:hook`), drush's canonical order. Never `cr`/`cim` before `updb` on a cross-version pull. If you already pulled and hit the error, `drush updb -y` alone recovers it (runs `system_update_11201`) — no table drop needed.

**Tooling:** this is the post-pull step in augustash `ddev-pantheon-db` (`ddev db`). Versions ≤1.0.4 ran `cr && cim && updb` (backwards → faceplants on any cross-version pull); **1.0.5** switched it to `composer install && drush deploy`. On ≥1.0.5 the addon handles it; older sites need the bump or a manual `updb` after pulling. Note the addon's guard: unforced `ddev db` skips when a DB already exists (`TABLE_COUNT > 1`), so it won't clobber a migrated local — but `ddev db -f` forces, so don't force-pull prod's old DB over a migrated local mid-upgrade or you redo the whole migration.

First hit: mace D10→D11 upgrade, 2026-07-13 — same upgrade wave that surfaced the symfony/runtime WSOD (d11-symfony-runtime) on mymspconnect.

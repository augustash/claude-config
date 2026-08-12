# Force a fleet sync — run the collectors manually on GitHub

V.I.N.CENT's per-site collectors — updates, health, watchdog + WordPress logs,
deploy history, screenshots — do **not** run on Pantheon. They shell into each
site with `terminus` (SSH, Node), which a Pantheon container has none of, so
they live in **`augustash/vincent-collectors`** and run on GitHub Actions,
POSTing shapes-and-counts back to the tool's ingest API. Only the sweep and the
uptime probes run in V.I.N.CENT's own Pantheon cron.

So the board, Updates and Health refresh only as fast as those CI jobs: roughly
**twice a day** (cron `20 6,18 * * *`), screenshots **weekly** (`0 5 * * 1`).
When you need fresh data *now* — after a mass upgrade, or when a number looks
stuck — trigger a run by hand; the workflow already supports it via
`workflow_dispatch`.

**GitHub UI:** `augustash/vincent-collectors` → **Actions** → **Fleet
collectors** → **Run workflow** → pick the **`collector`** input (`all`, or one
of `updates` / `health` / `logs` / `screenshots` / `workflows`) → **Run**.

**CLI:** `gh workflow run collectors.yml -F collector=all` (or a single
collector); add `--ref main` if needed.

Caveats:

- The Pantheon collectors (updates / health / logs / workflows) only run when
  `PANTHEON_ENABLED` is set, and use the **bot-user** token in an *environment*
  secret — scoped to the lowest role that can read, so the token, not its
  storage, is what bounds the blast radius. See [[pantheon-secrets]].
- A full run fans `terminus` into ~158 sites: a few minutes plus CI minutes, so
  don't spam it. Results land on the board as each collector POSTs back, not all
  at once.
- Screenshots need no Pantheon token (public homepages) and run on hosted
  runners; logs run on hosted runners too, reducing raw log lines to counts
  before anything leaves the VM.
- A Drupal-side "Sync now" button is possible — the same `workflow_dispatch`
  called from the backend with a GitHub `actions:write` token — but that token
  does not exist yet; until it does, this manual path is the way.

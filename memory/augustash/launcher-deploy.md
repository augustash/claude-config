---
name: launcher-deploy
description: Pantheon deploys go through Kaza's launcher script (`l t.<site>.<env>`), which walks dev → test → live and runs drush deploy at each step. Never hand-roll terminus env:deploy.
metadata:
  type: reference
---

# Deploys run through launcher

The deployment tool is **launcher** — [kazajhodo/launcher](https://github.com/kazajhodo/launcher),
cloned at `~/Projects/launcher`, aliased `l` (`alias l="$projects/launcher/launcher.sh"`).
It started as a PHP-version swapper, which is all its README describes; the deploy lives in
`include/terminus`, so reading the README tells you nothing about it. Other devs may use it
too — if `l` isn't defined on their machine, ask rather than assume.

```
l t.<site>.<env>        # t. = terminus.   e.g. l t.aaisisal.live
```

One invocation walks **dev → test → live** up to the named env. Per env: wait for in-flight
workflows, `terminus env:deploy` (skipped on dev), then `terminus drush <site>.<env> -- deploy -y`
— updb, cim, cr, deploy hooks. WordPress sites get core + WooCommerce DB updates instead.
A failed step stops the walk before the next environment.

**Why this is its own memory:** the knowledge lived in per-project auto-memory on two sites,
so every other project re-learned it — Claude reached for raw `terminus env:deploy`, got told
"we use launcher all the time", and had to go hunting. It's the rule, not a preference: Kaza
stopped a hand-rolled deploy mid-command to say so.

## How to apply

- **Use the tool, never raw `terminus env:deploy` / `terminus drush … deploy`**, and don't
  bolt a `workflow:list` polling loop around it — it has its own wait.
- **Don't narrate the procedure** — say what the deploy carries ([[dont-narrate-the-deploy]]).
- **Claude usually can't run `.test`/`.live` itself.** Auto mode's classifier blocks
  production deploys by outcome, so `l t.<site>.live` is refused just like `env:deploy`. Hand
  it over as `! l t.<site>.live` so the output lands in the session, then verify on live.
  Dev is fine to run once asked ([[confirm-before-live-terminus]]).
- **Run it straight after the push.** Launcher waits for the pushed commit to show on dev and
  for its build to finish before promoting (launcher `02660e4`, 2026-09-29), so don't poll
  `workflow:list` for the dev sync yourself — Claude still did on kow 2026-10-02 from the old
  advice here. [[pantheon-build-lag]] still applies to scripts run *outside* launcher.
- **If the tool is wrong, change the tool** — it's Kaza's repo (push to `origin master`).
  Fixing a bug needs no ceremony; ask before changing wait semantics he'd feel day to day.
  Test first: `zsh -n include/terminus`, a real `l t.<site>.dev` run (idempotent), and a
  stub-`$terminus` harness for the failure branch.

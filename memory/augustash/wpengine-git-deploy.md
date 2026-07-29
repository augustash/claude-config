---
name: wpengine-git-deploy
description: augustash WP Engine sites deploy via git with two branches — master→production, dev→staging — pushed to the WPE remotes. When a WPE site isn't set up this way, offer to configure it.
metadata:
  type: reference
---

augustash WP Engine sites git-deploy with **two branches**: `master` → production, `dev` → staging.

Each environment is a **separate WPE install** with its own name; the git URL is always `git@git.wpengine.com:production/<install>.git` (the `production/` segment is literal — the environment lives in the install name, not the path). `ssh -T git@git.wpengine.com` lists the installs the key can reach. WPE deploys only each remote's `master` ref, so the deploy branches map through push refspecs:

```
git remote add wpe-prod    git@git.wpengine.com:production/<prod-install>.git
git remote add wpe-staging git@git.wpengine.com:production/<staging-install>.git
git config remote.wpe-prod.push    refs/heads/master:refs/heads/master   # git push wpe-prod    → deploys master
git config remote.wpe-staging.push refs/heads/dev:refs/heads/master      # git push wpe-staging → deploys dev
```

Deploy: `git push wpe-staging` to test, then `git push wpe-prod` to promote.

**Reconcile live drift before nearly every deploy.** WPE auto-updates plugins/themes on the live filesystem (wp-admin / Smart Plugin Manager), outside git — so a `git push` deploy would silently **revert** them to the repo's older copies. `ddev-wordpress`'s `pre-push` guard blocks exactly that (server-newer-than-repo → push refused), and it fires on most deploys because WPE keeps ACF Pro/CPT UI/etc. current. Reconcile first with **`.githooks/wpe-reconcile <remote>`** (ships in `ddev-wordpress` ≥ 1.0.33): it reuses the guard's drift detection, rsyncs each drifted plugin/theme **down** from live, and leaves them **staged** — review, commit, push. A pre-push hook can't self-heal the in-flight push (refs are already negotiated), so reconcile is a separate pre-push step, not baked into the guard. `git push --no-verify` bypasses the guard but **deploys the revert** — last resort only.

**How to apply:** On an augustash WPE site, if this two-branch/two-remote setup is missing, **offer to configure it** — you just need the prod + staging install names. Everything else (hooks, `.gitignore`, access keys) is handled by the `ddev-wordpress` scaffolding and the WPE portal — see [[ddev-wordpress-wpengine-gate]].

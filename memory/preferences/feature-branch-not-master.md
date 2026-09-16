---
name: feature-branch-not-master
description: Speculative or in-review work goes on its own branch and multidev — never pushed to master, which auto-deploys to dev
metadata:
  type: feedback
---

**New features being built for review go on a feature branch and its multidev only. Never
push them to `master`.** On Pantheon, `master` auto-deploys to the dev environment and is the
trunk that flows dev → test → live, so pushing exploratory work there puts it in the
deployment path and in front of the rest of the team.

**Why:** Dane (kow, 2026-08-07), after a new admin module was pushed to master alongside its
multidev branch: "this shouldn't be in main dev only on the branch and multidev." Even with
the module disabled, the code and its `core.extension.yml` entry sat on master, one `cim`
away from installing itself on dev, test or live.

**How to apply:**

- Create the multidev first, then push only to its branch: `git push origin master:<branch>`
  is wrong once work has started — commit on the feature branch itself
  (`git checkout -b <branch>`) and push `<branch>:<branch>`.
- Fixes for reported bugs still follow the normal master → dev → test → live path; the branch
  rule is for features being built or reviewed.
- If it lands on master by mistake and nobody else has pushed since, reset master to the last
  legitimate commit and `git push --force-with-lease`, after confirming every commit exists on
  the feature branch. Tag the old tip locally first. Tell the team, because anyone who pulled
  in the meantime has to reset.

See [[commit-handoff]] for who commits what.

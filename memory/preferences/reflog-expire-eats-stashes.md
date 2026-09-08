---
name: git reflog expire --all destroys every stash
description: Before running reflog expire, gc --prune, or any "clean up unreachable objects" recipe — the stash list IS a reflog, so --all silently deletes it.
type: feedback
---

**Never run `git reflog expire ... --all` on a repo with stashes.** `git stash list` is not a
list of refs — it reads the reflog of `refs/stash`. `--all` includes that reflog, so expiring
unreachable entries deletes every stash except the one `refs/stash` itself points at, and a
following `gc --prune=now` destroys the objects. There is no warning and no confirmation.

Done on wps 2026-09-08 to remove one unwanted commit, taking six stashes dating back to 2022
with it. Checking `git stash list` first and seeing them there is not protection — that was
done, and the command was run anyway.

**Why it's worth a rule:** the usual recipes for "get rid of an unreachable commit" are all
written as `git reflog expire --expire-unreachable=now --all && git gc --prune=now`. That
recipe is fine on a scratch clone and quietly destructive on a working one, and stashes are
exactly the kind of thing nobody has a second copy of.

**How to apply:**

- **Find what actually holds the object first.** `git for-each-ref --contains <sha>` and
  `git log --all --source --grep=...`. In the wps case the commit was still reachable from
  `refs/remotes/origin/master` — it had been pushed — so no amount of local expiry would ever
  have removed it, and the whole operation was destroying data to solve nothing.
- If it genuinely is only in a reflog, expire **that one ref**:
  `git reflog expire --expire-unreachable=now refs/heads/master` — never `--all`.
- Recovery, if the object survives: `git stash store -m "<message>" <sha>`. `refs/stash` alone
  is not enough, since `stash list` needs the reflog entry, and `update-ref` won't write one
  when the ref value doesn't change. Anything only in the expired reflog is unrecoverable.
- A rewritten commit that was already pushed is a remote problem, not a local one. Say so and
  let the developer decide on the force-push; don't reach for local surgery.

Pairs with [[commit-messages]] — the amend that started this was stripping an attribution
trailer, which is worth doing, but only before the push.

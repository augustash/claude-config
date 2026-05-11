---
name: Prefer merge over rebase when pulling
description: Use `git pull --no-rebase` (or plain `git pull` when default is merge) instead of `git pull --rebase` when integrating remote work into a local branch
type: feedback
---

When the remote rejects a push because it has work the local branch doesn't, integrate by **merge**, not rebase. Use `git pull --no-rebase origin <branch>` (or plain `git pull` if the repo's default is merge) before re-pushing.

**Why:** Rebase rewrites the local commits' parents, which can be disorienting in collaborative repos and erases the actual history of "these two streams of work happened concurrently." Augustash convention is to preserve that — the merge commit is information, not noise.

**How to apply:** Default to merge whenever pulling. Only use rebase if the developer asks for it explicitly. This includes `--rebase` flags, `git rebase` invocations, and "clean up the history before pushing" framing. None of those happen unprompted.

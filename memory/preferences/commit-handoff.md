---
name: commit-handoff
description: Claude commits + pushes shared claude-config memory work. Developer commits and pushes all project-level work after reviewing the diff.
metadata:
  type: feedback
---

Two distinct ownership zones for committing:

- **Shared memory (`vendor/augustash/claude-config/`):** Claude commits and pushes. This is package distribution — leaving local-only edits would defeat the purpose since other projects depend on the published package.
- **Project repo:** Developer reviews the diff, commits, and pushes. Even when Claude wrote the code, the dev reviews and commits to maintain authorship signal and review discipline.

**Why:** Developer wants to review every change to project code before it's committed. Shared memory is meant to flow back to the team automatically; project work should not.

**How to apply:** After finishing project work, prepare a clean state (files saved, tests passing) and stop — don't run `git add` or `git commit` for project files. State what was changed, surface the diff if helpful, and let the dev take it from there. For shared memory under `vendor/augustash/claude-config/`, follow the package's own commit handoff convention (steps 1–4 in its CLAUDE.md) — that ends with Claude committing and pushing.

⚠ **"Go ahead" covers that batch, not the session.** The way this rule actually gets broken is not by ignoring it — it is by being handed the commits once, for one clearly-scoped set of changes, and quietly treating that as standing permission for everything after. On ar-md (2026-08-02) a single "go for it" early in a session turned into **31 unreviewed project commits**, which then had to be unwound with `git reset --soft`. Nothing was lost, but the review the rule exists to protect never happened.

So: an approval is consumed by the work in front of you. When the next distinct piece is ready, hand it back and ask again. And if committing is delegated for a long stretch, **commit at the granularity the dev would have chosen** — the same run produced ~18 commits for one feature, several of them a single CSS value, which fails the revert test as badly as one giant commit does.

Staging is the useful middle ground: `git add` the finished work so it is one reviewable set and say so, without taking the commit.

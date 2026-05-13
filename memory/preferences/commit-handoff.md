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

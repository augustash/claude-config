---
name: Memory organization structure
description: How to organize memories across all projects — idea/specific.md pattern, committed to repo for team context
type: feedback
---

Organize memories using an idea/specific.md directory pattern rather than flat files.

**Structure:** `{idea}/{specific}.md` — the directory is the broad topic, the file is the specific detail.
Example: `apis/convertcart.md`, `apis/commerce.md`, `modules/update-audit.md`

**Per-project memories go in the project repo** (`.claude/memory/`) and should be committed so all developers on the project share the same context.

**User-specific preferences go in `~/.claude/CLAUDE.md`** — never in `~/claude-config/` or per-project `.claude/memory/`. Both of those are git-committed and shared with the team. Things like "this dev is strong in X, learning Y", personal workflow preferences, or individual communication style belong in the user's own home `~/.claude/CLAUDE.md`, which Claude Code loads into every session for that user only. If a memory file has `type: user` in its frontmatter, it does not belong in team-shared memory by definition.

**Where to find project context:** Every project stores its memories at `.claude/memory/` in the project root, with a `MEMORY.md` index. When starting work on a project, check `.claude/memory/MEMORY.md` for existing context before asking the user to re-explain things.

**What to save:** The purpose of memory is to retain context that would take significant effort to re-discover — saving duplicate work across sessions and developers. Before saving, ask: "Would another dev (or a future session) spend real time re-piecing this together?" If the answer is in the code or a quick `git log`, skip it.

Save:
- **Big-picture integration knowledge** — when understanding something requires processing across multiple files, systems, or external docs (e.g., API contracts, auth flows, data pipeline behavior)
- **Architectural decisions with non-obvious reasoning** — when a choice was made for reasons a future dev might not realize and could undo (e.g., "localStorage instead of sessions because sessions poison Varnish cache")
- **Reusable debugging approaches** — methodology that applies beyond a single fix, especially across projects (e.g., "how to track down what's causing max-age: 0 in Drupal"). If the approach is project-agnostic, it belongs in global memory (`~/claude-config/memory/`), not per-project.

Skip:
- Completed task summaries — the work is in git history
- Point-in-time snapshots — re-run the tool instead of trusting stale data
- Resolved bugs — the fix is in the code, the commit message has the context
- Anything easily derived from reading the current codebase
- Trivial context that takes only a moment to figure out

**How to apply:** When saving a new memory, determine the idea category first. If a directory for that idea exists, add a specific file. If not, create the directory. Never dump multiple unrelated topics into one file.

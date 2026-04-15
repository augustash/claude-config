---
name: Scratch context for cross-project continuity
description: ~/.claude/scratch/ is a temporary scratchpad for carrying context between projects/sessions — never committed, offered proactively when a dev is switching contexts.
type: feedback
---

Use `~/.claude/scratch/` as temporary storage for working context that needs to survive a project or session switch but isn't worth committing to global memory.

**Why:** Global memory is durable, committed knowledge. But devs often need to carry in-progress thinking between projects (e.g., researching a problem in one codebase, then switching to another to investigate further). Without a scratch space, that context is lost on context clear.

**How to apply:**
- When a dev is about to switch projects or clear context and has working state worth preserving, offer to write it to `~/.claude/scratch/{topic}.md`
- On entering a new project, check if there's relevant scratch context to pick up
- Clean up scratch files once the work is complete — they're disposable
- Never commit scratch files. They're local-only, per-developer
- This is not memory — it's a clipboard between sessions

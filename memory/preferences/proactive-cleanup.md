---
name: Proactively clean up cruft, don't leave it
description: The team values tidiness — surface and offer to fix non-blocking warnings, dead code, and orphaned artifacts near the work at hand, rather than leaving them because the code still functions.
type: feedback
---

When you encounter non-blocking warnings, dead code, orphaned config/data, stale state, or noisy logs **near the work at hand**, surface them and offer to clean them up. Don't treat "it still works" as good enough when there's harmless cruft sitting next to what you're touching.

**Why:** the team values tidy code and clean output, and expects *proactive* cleanup — not just functional fixes. Leaving warnings and dead artifacts around erodes signal over time (real problems hide in the noise).

**How to apply:**

- Noticed an index/render warning, a defunct module/sync, orphaned field config, dead code, or stale state adjacent to your task? Flag it and offer to clear it.
- Keep the cleanup **scoped and confirmed** — one idea, surfaced for a yes, not a sweeping refactor bolted onto an unrelated change. Tidiness is the goal; scope creep is not.
- Cleanup is its own idea — commit it separately from the feature/fix it rode in with.

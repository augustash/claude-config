---
name: Reference script files, don't embed them in memory
description: When a memory note would contain a script or reusable code artifact, store it as a tracked file in the package and link to it by path — never paste the body inline, even for small scripts.
type: feedback
---

When a shared memory would include a script, template, or any reusable code artifact, **save it as a real tracked file** in the package (e.g. under `templates/`) and **reference it by relative path** from the note. Don't embed the code body in the markdown — this holds even for small scripts.

**Why:** a referenced file is single-source, lintable, and version-tracked; you can update it without editing prose, and it can't silently drift from the real working copy. Embedded code blocks rot — they bloat the note, fall out of sync with the deployed version, and can't be syntax-checked. Keeping scripts as files "keeps things tidy over time" (dev's words).

**How to apply:**

- Memory would contain a script/template → write the file under `templates/` (or the fitting dir), then in the note link it like `[`templates/foo.php`](../../templates/foo.php)`.
- Keep only *config/wiring snippets* (a few lines of YAML/JSON) and the rationale inline — those aren't standalone artifacts and have nowhere better to live.
- Pairs with [[pantheon-quicksilver-cache-warmer]], which follows this pattern: the drop-in warmer is a tracked template file, the note just references and explains it.

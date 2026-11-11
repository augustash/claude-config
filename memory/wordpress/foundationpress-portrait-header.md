---
name: FoundationPress header breaks on wide portrait windows
description: The hamburger shows and search hides in any portrait window from 640px up while the desktop menu only hides below 1024px; plus the parent's fixed CSS version and a build that won't run on current Node.
metadata:
  type: reference
---

Found on Enterprise Minnesota's `foundation` / `foundation-child` theme (FoundationPress
based), 2026-11-10. Likely shared by other augustash WordPress sites on that parent.

**Symptom:** a desktop browser window taller than it is wide (Kaza's: 1062 × 1333) shows
the desktop menu *and* the hamburger, with search gone, until the window is widened past
its height. Reads as a breakpoint bug at ~1060px; it's orientation.

**Cause:** `.menu-trigger` shows under `(min-width: 40em) and (orientation: portrait)` and
`.search-wrap` hides under `(orientation: portrait)`, both unbounded, while
`.desktop-menu` only hides under `medium down` + portrait. **Fix:** bound both to the same
tablet range, `breakpoint(medium only)` / `medium down`, so desktop widths stay desktop in
any orientation.

**Two traps around fixing it:**

- **The theme's build doesn't run on current Node:** `gulp-sass` 3 uses `node-sass`.
  Edit the SCSS (the source of truth) and make the identical change in
  `dist/assets/css/app.css` until the build is modernized.
- **The parent enqueues the child's `app.css` with a hardcoded version** (`2.10.4`), and
  Pantheon serves CSS with a 7-day max-age, so CSS changes reach visitors a week late.
  The child now overrides `main-stylesheet`'s version with the file's mtime.

Also: the theme hides the whole `.blank` header area below 40em, so anything added beside
search vanishes on phones. Put phone controls in the off-canvas menu instead.

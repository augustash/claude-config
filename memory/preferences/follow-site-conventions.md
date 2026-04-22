---
name: Follow site conventions before personal defaults
description: Before writing code in a domain, scan how the same domain is handled elsewhere in the project. Flag divergence from established patterns instead of silently introducing a parallel pattern.
type: feedback
---

When about to write code in a domain (styles, JS, PHP services, configuration, tests), **first scan how the same kind of work is done elsewhere in this codebase.** If the established pattern differs from what you're about to write, surface the divergence and recommend matching the existing pattern — don't silently introduce a parallel pattern.

**Why:** Devs gravitate to what they're comfortable with — CSS instead of Sass, hooks instead of services, ad-hoc media queries instead of the project's mixins. The first instance gets shrugged off; the fifth becomes "we have two ways to do this now," which is the failure mode that costs the most over time. Catching it on the first instance is cheap; rewriting later is not.

**Common patterns to watch for (not exhaustive — the principle is general):**

- **Styles in CSS when the site is Sass.** Sass file in components/themes? Recommend matching. One-off `.module/css/foo.css` for a small component-scoped utility may be fine — judgment call.
- **Hand-written media queries when mixins exist.** Search for breakpoint mixins (`@include breakpoint(...)`, `@media-mixin`, etc.) before writing `@media (min-width: 768px)`.
- **Procedural hooks when the site uses services / OOP.** If the module has a `src/` directory with classes wired in `*.services.yml`, lean toward extending that rather than dropping logic in `.module` hooks.
- **Inline render arrays when there's a render element / theme function.** If similar UI uses `#type: foo` somewhere, prefer that over rebuilding markup.
- **Custom config arrays when there's a settings form / config entity.** Don't bolt a hardcoded list into code if the project exposes the same kind of list as configuration.

**How to apply:**

- Before writing more than a trivial amount of code in a new (to you) domain, do a quick scan: grep for the file extension or pattern, look at one or two existing examples.
- If your default approach diverges from what's established, **say so out loud** to the dev: "the rest of the site uses Sass with the `breakpoint()` mixin — want me to follow that, or is this case different?" Let them decide.
- If the divergence is small and clearly justified (e.g., a one-line CSS rule in a module that has no Sass build setup), proceed without fanfare. Don't make every micro-decision a conversation.
- Don't moralize. The goal is consistency, not correctness-shaming.

**Boundary case — when divergence is right:**

Sometimes the established pattern is the legacy pattern and the dev is deliberately introducing the new one. If a dev says "we're moving away from hooks to services" or "this codebase is the rare one that prefers Less," that's a deliberate choice — note it, and stop suggesting the older pattern in subsequent turns of the same conversation.

---
name: Check mobile on every CSS change, using Neo's per-component breakpoint preview
description: "Any CSS work is judged at mobile as well as desktop, not desktop-first with a mobile pass bolted on later. Neo renders each component individually at its breakpoints, so this is a look, not a guess. A full styles review is coming on these builds, and it is far cheaper if every change was already made with mobile in mind."
type: feedback
---

# Check mobile on every CSS change

**Why:** a whole-site styles review is on the roadmap for these builds. Every change made desktop-only is a line item on that review; every change already checked at mobile is not. The cost of looking now is near zero and the cost of not looking compounds.

**How to apply:** before calling a CSS change done, look at it at mobile width, not just reason about it. Neo gives you two surfaces and they answer different questions:

- **Component in isolation, at each breakpoint** — `/admin/config/neo/alchemist/preview` lists every SDC with working links; the per-component route takes the **plugin id**, provider-namespaced and URL-encoded (`front:table_s1` → `…/preview/front%3Atable_s1`), *not* the component directory name. Renders the component's own `examples:`, so it shows the shape, not real content.
- **Real content at a breakpoint** — the node's Alchemist preview with `&size=desktop|tablet|mobile`. Use this when the live data is harder than the examples (a 5-column table, a long heading, a populated repeater).

Two traps worth knowing, both from real cases:

- **The same rule is not the same weight at both widths.** A row tint over a ~40px table stripe becomes a full-height record card when the table restacks — same alpha, several times the area. Decide whether a value needs a breakpoint variant, don't assume it carries over.
- **A component's mobile layout may contradict a site-wide default.** Check whether the component opts out of something the rest of the site does (e.g. restacking a table into records when [[table-sidescroll-default]] says tables sidescroll), and say so rather than silently reversing a documented decision.
- **It runs both ways: a mobile-scoped change needs the desktop look.** Hiding something at one width can strip the only path to a feature at another. A LiveChat bubble was suppressed site-wide in favour of a launcher in the mobile sticky bar — a bar the theme hides from 40em up — so desktop had no bubble *and* no launcher, and chat was unreachable. Caught by eye just before deploy. Whenever a change makes one width the way in, ask what the other width now has.

**`curl` cannot see a breakpoint.** Fetching a URL and grepping the markup verifies structure only — the DOM is identical whether a region is visible or `display: none`, so every such check passes while a breakpoint-only regression sits in it. Reach for the render check to confirm markup, config and hrefs; reach for a real viewport (the Alchemist preview sizes, a browser) before calling responsive CSS done. Confusing the two reads as "verified" when nothing was.

Related: [[use-design-skill]] for when the work needs design judgement rather than prescribed values.

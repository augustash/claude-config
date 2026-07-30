---
name: Tables sidescroll on narrow screens — they do not restack into records
description: "The default for any data table is horizontal scroll with a visible scroll cue, NOT the common pattern of restacking each row into a labelled card below a breakpoint. Columns are what make tabular data comparable, and a stack of records destroys exactly that. Applies unless a specific table is argued out of it."
type: feedback
---

# Tables sidescroll; they do not restack into records

**Why:** the columns are the point. A table is tabular because the values are meant to be read against each other, and restacking each row into its own labelled card removes the comparison while turning a 20-row lookup into 20 cards to page through. Sidescrolling keeps the table a table at every width.

**How to apply:** put the table in the shared `overflow-x: auto` wrapper and let it scroll. Pair it with a **visible scroll cue** — the native scrollbar is not a strong enough signal that columns exist off-screen, and on touch it may not render until the user already scrolls. On the DMX build that is `js/table-scroll-hint.js` driving `.scroll-hint` for any `.dmx-table-wrap`; the pattern is a nudging `»` pinned to the right edge of a positioned shell wrapping the scroller, shown while `scrollWidth - clientWidth - scrollLeft > 2`.

Two things this repeatedly gets wrong:

- **The cue must live outside the scrolling element**, or it scrolls away with the content. Wrap the scroller in a positioned shell in JS rather than making every template carry a wrapper.
- **Measure on resize, not just on scroll.** A collapsed accordion panel measures 0 wide, so the initial reading is wrong and the cue never appears. A `ResizeObserver` on the scroller catches the panel opening, a window resize and a reflow with one mechanism.

This reversed an earlier per-component decision on the DMX build, where a fault-code table restacked into records on the argument that you cannot scan a column while panning sideways. That carve-out is subsumed: sidescroll is the default for every table. If a specific table genuinely needs records, that is a case to argue explicitly, not a default to fall back to — see [[mobile-breakpoint-check]] for checking either against the real thing.

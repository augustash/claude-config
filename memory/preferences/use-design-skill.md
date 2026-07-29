# Load the design skill when the work has to match something

Load `frontend-design` BEFORE writing code whenever the task is to make
something look like an existing reference, or to decide how it should look at
all: matching a component to another page's treatment, giving a component a role
in the system ("make this the masthead"), building new UI, or reshaping an
existing look.

**Not needed for prescriptive moves.** When the dev has already made the design
decision and is handing over a value — `max-width: 78%`, `padding-left: 16px`,
"remove the dots", "arrow to the right of the title" — just do it. The judgment
has already happened; loading the skill adds nothing.

**Why:** the distinction is whether any design judgment is left. A prescriptive
tweak has none. Anything that has to *match* does, and that is exactly where it
goes wrong without a grounding pass — the failure is picking the wrong thing to
match. A "make this the page masthead" task was built out of the section-header
utilities (green eyebrow, fixed type step) when the codebase already had a
masthead rung (muted eyebrow, fluid clamp) that the catalog pages and the
sections component were wired into. It looked fine in isolation and read as a
section header at the top of a page. A grounding pass finds the rung; eyeballing
it does not.

**How to apply:** invoke it at the START, then go and read the reference before
designing anything — the actual computed styles of the thing being matched, and
the shared layer underneath it. Prefer joining an existing selector over
restating its values, so the two stay matched when one changes. On a mature
design system the "one real risk" the skill asks for should usually be applying
the system's own signature device somewhere new, not adding a new device. See
[[follow-site-conventions]] for the wider version of that instinct.

Pair with [[comments]] — the WHY behind a non-obvious visual choice (a magic
number, a specificity workaround, a token indirection) belongs in the CSS.

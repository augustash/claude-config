# Load the design skill for any styling/design work

Whenever the task is visual — writing CSS, styling a component, laying out a
page, choosing type/color/spacing, or reshaping existing UI — load the
`frontend-design` skill BEFORE writing any code. This is a standing rule, not a
per-task judgment call.

**Why:** it materially improves the output. Left to default behavior the result
drifts toward templated, generic-looking design; the skill forces an explicit
plan (color/type/layout/signature) and a self-critique pass against that plan
before any code gets written. The dev has asked for this specifically after
seeing the difference.

**How to apply:** invoke the skill at the START of the work, not partway
through. Then ground the plan in what already exists — read the project's brand
token layer and the sibling sections/components first, and extend that
vocabulary rather than inventing a parallel one. On a mature design system the
"one real risk" the skill asks for should usually be applying the system's own
signature device somewhere new, not adding a new device. See
[[follow-site-conventions]] for the wider version of that instinct.

Pair with [[comments]] — the WHY behind a non-obvious visual choice (a magic
number, a specificity workaround, a token indirection) belongs in the CSS.

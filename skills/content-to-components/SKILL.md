---
name: content-to-components
description: Turn surviving legacy content into a component tree — decide what shape the content actually is, choose reuse/extend/build-new, re-type legacy markup as data, and verify the built page. Use when building a page or section out of audited content, composing sections in a build script, deciding whether content wants a table/accordion/prose block, lifting applicability or scope out of prose, or writing the verify pass for a composed page. NOT for deciding WHICH content survives (that is content-audit, which runs first), and NOT for authoring the component itself — the project's component skill owns that once you know the shape you need.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Content → components

**The job:** the audit has decided this content survives. Now decide what shape it *is*, and
build it. This is the step between "these nodes keep" and "here is the component tree".

Runs **after** [content-audit](../content-audit/SKILL.md), usually much later and once per
section rather than once per project. If you are still deciding what migrates, you are in the
wrong skill.

Two others own the halves either side of this one, and both should be loaded before building:

- **`frontend-design`** — whenever presentation judgment is left: a new section's treatment, or
  matching how an existing section already looks. Load it *before* coding, not after. Skip it
  only for prescriptive moves where the value was handed to you. The failure it prevents is
  matching the wrong thing — read the reference section's computed styles and join its pattern
  rather than restating values.
- **The project's component skill** (on a Neo project, `neo-component`) — how to actually author
  or extend a component once you know what shape you need.

## Establish the constraint before deciding the shape

The same content takes a different shape depending on what the system can render and what you
are permitted to add. Settle two things first, because they change the answer:

1. **What components already exist**, and what each can actually carry. Read the props, not the
   name — a component's title rarely tells you whether it takes a video, a repeater, or an
   anchor.
2. **Whether new components are on the table** for this piece of work. Reuse-only,
   extend-permitted and build-new are three different briefs.

Then work in that order — **reuse → extend → build new** — and make the escalation explicit:

- **Reuse** if an existing component fits the content's real shape. It fits if the content maps
  onto its props without contortion, not if it can be forced in.
- **Extend** the component the section already uses, in preference to introducing a second one
  doing nearly the same job. One additive optional prop usually beats a near-duplicate
  component, and it inherits the behaviour, styling and editor UI already proven there.
- **Build new** only when the content's shape genuinely isn't in the system. Flag it as a
  decision (`⚠ NEW COMPONENT`) with what it costs — never silently build one, and never
  silently reshape the content to dodge the gap. Quietly flattening a table into prose because
  no table component exists is a content decision disguised as a technical one.

If you're constrained to reuse only and nothing fits, **say so and describe the compromise**
rather than absorbing it. "This ships as prose because the hub has no table component, and it
loses the scan-down lookup" is a reviewable statement; silently shipping worse content is not.

⚠ **An editor-facing text field will strip markup you inject.** If you find yourself emitting
classes, ARIA or icon elements into a rich-text prop, check what survives the filter — a
restricted format keeps `<a href>` and throws away the class, the label and the icon, leaving
markup that renders as *nothing* and reads as a CSS bug. That is the signal you need an
extend (a real prop the component renders) rather than cleverness in the content.

## Legacy markup encodes layout, not meaning. Re-type it as data

Porting the old HTML carries its presentation decisions forward into a system that renders them
differently. Extract the *relationships* and rebuild:

| Legacy pattern | What it actually means | Rebuild as |
|---|---|---|
| `rowspan`, or an empty first cell meaning "same as the row above" | these rows share a parent | a **panel with its own heading**, one per parent |
| `1. … <br> 2. … <br>` inside a cell | sequential steps | a real ordered list |
| the same closing sentence inside every cell | one instruction, repeated | said **once**, after the list |
| a paragraph restating something another page already explains | an unmanaged copy | a **link** to the one place it's written |
| "the N, NP, LP and CSW series work this way" | *who this content is for* | a **field on the component**, not a sentence |
| a run of `<h5>` + link, repeated down the page | a lookup keyed on something the reader knows | a **table**, one row per entry |
| an image of a table | data someone gave up on | **re-typed as a real table** |

**The rowspan case is the one that bites.** A merged cell survives the desktop table and then
vanishes on mobile, where responsive tables turn each row into its own labelled record and
continuation rows render with no parent at all. Don't fold the alternative either — an N-item
cause list beside an N-item fix list asks the reader to pair them by position across a gap, and
the pairing *is* the content. If a group has its own heading, its own anchor and its own rows,
it's a panel. Once you stop assuming one table, the problem disappears.

**An image of a table is not a table.** It cannot be searched, read on a phone, or reached by
the table's own filter. Re-key it. The only judgement is whether the data is still worth
carrying at all — which is an audit question, so ask it rather than assuming the answer is yes.

## Applicability is metadata, not a sentence

Support content constantly names who it is for — which models, series, revisions or regions it
covers — and legacy pages bury that in the middle of a paragraph. It is the *first* thing a
reader needs and the one thing they scan for: is this about my unit? Buried in prose they have
to read the paragraph to find out, and it cannot be filtered, listed or checked for staleness.

So when a block's scope is stated in its copy, **lift it onto the component** — provided the
component has, or can take, a field for it. The test:

- It names **specific** hardware or variants, not a general audience. "For CSW and CMW series"
  qualifies; "for most installations" does not.
- It scopes **this block**, not a step inside it. A caveat on one instruction stays in the copy.
- The list is **closed and checkable** — you could verify it against the catalog.

Then remove the sentence. Leaving both means the page states its scope twice and the two can
disagree; **assert the absence** in the verify pass, because a later edit restoring the inline
version is silent. Treat it as content, not a relationship — labels the editor types, not
references resolved against a product entity. Applicability copy ages, but so does the catalog,
and coupling them makes a content edit into a data migration.

If the component has no such field, this is an **extend**, not a rewrite: one additive optional
prop on the component the section already uses. If extending isn't on the table, leave the
sentence and record it — a scope statement is not something to drop for want of a field.

## Choosing the container

**Pick by what the reader is doing:**

- *scanning for their row* (a code, a model, a symptom) → a **table**, filterable past ~15 rows
- *a set of independent questions* → an **accordion**, shut by default
- *one continuous explanation* → a **prose block**
- *a procedure* → ordered steps, with the warning that people skip pulled out above them

**Tighten the key column.** A lookup table works when its first column reads down like an index
— short scannable labels. Detail that pads a label belongs in the adjacent cell.

**A repeated cell value is a column, not noise.** If a grouping label would be blank on
continuation rows, repeat it instead — a filter that *marks* matching rows will light only the
first of a group otherwise, and search is the whole point of a long table. Visual stutter is
the cheaper cost.

**Say it once in the header, not once per row.** Link text repeated identically down a column
("One-page wiring diagram", ×82) is a column restating its own heading. An icon plus an
`aria-label` carrying the row's identity says more in less. Watch the byte cost though —
per-row labels are real weight, and the rows have to be in the DOM if the filter is
client-side, so a long table is inherently a heavy page. Know the number before someone reads
the next byte delta as a leak.

## Links and anchors

**Check that links resolve, not just that the page renders.** A section built from link lists
is mostly links, and a rendered page tells you nothing about whether they land. Resolve every
one against the redirect table or the file store, then sort the failures — the split is what
matters:

- **Already dead on the legacy site** (no file, no record): do not port it. Find the live
  replacement, or drop the heading it justified. Porting a link that has been broken for years
  is migrating a defect.
- **Migrated but unrouted** (the file exists under a new path with no redirect): link it at its
  real destination, and log the missing redirect for inbound legacy traffic.

⚠ **Don't test this by matching filenames.** A migration that reorganises files renames them,
so a basename comparison reports mass false failures. Match on the redirect table, or on
content hash.

**Check how anchors are derived before relying on them.** On some platforms a heading's `id` is
slugged from its title, so re-wording a heading silently moves its anchor and breaks every
inbound link — while a sibling `anchor` prop on the same component may be emitted verbatim.
Those behave differently and the difference is invisible in the source. Verify against rendered
output.

⚠ **An anchor that is a redirect target is an interface.** Once a retired URL points at
`#some-table`, renaming that table breaks inbound traffic with no error anywhere. Assert those
anchors in the verify pass and say in the code that they are load-bearing.

**Re-point dead outbound links** at the new site as you go, and note any with no destination yet
rather than leaving them silently pointing at the old domain.

**Write each fact once and link to it.** Where two lookup paths need the same explanation, one
holds it and the other points at it by anchor. Re-wording it then can't leave a stale copy
behind. Same principle as the audit's merge/group test, applied inside a page.

## Building sections in code

Sections may be composed in a build script rather than clicked together, because a 22-row table
is easier to get right and to review as a diff, and a verify pass can assert the result.

**Such builders are scaffolding, not a source of truth.** The content rides up with the
database, and the moment anyone edits the page in the page builder a re-run silently discards
their work. **Retire them at handoff** — the DB carries the content by then, and the audit doc
remains the record of what was decided and why.

A composed section is a **construction, not a migration**: legacy tables get re-typed as real
data, `1. … <br> 2. …` prose becomes ordered lists, repeated boilerplate is stated once, and
dead outbound links are re-pointed.

## Verify what you built

Render the page and assert against the output, not against the props you just wrote. Three
kinds of check, and the last two are the ones people skip:

1. **Presence** — anchors, classes that prove a variant rendered, a distinctive string from
   each block.
2. **Counts, scoped to the thing being counted.** A page-wide tally cannot tell a missing row
   from an extra one elsewhere. Bound each panel's count by the *next* panel's anchor — and
   derive the expected list from the data rather than re-listing it by hand, because a panel
   left out of the tally does not merely go unchecked, it silently folds its rows into the
   count of the panel before it.
3. **Absence.** Every editorial decision that *removed* something needs a check that it stays
   removed: the scope sentence lifted onto a field, the discontinued content dropped, the
   legacy path that must never appear in a rendered href. These are the regressions nobody
   notices, because the page still looks right.

Name what each check is defending in its label. A failing assertion whose message is the
selector tells the next reader nothing about why it mattered.

## Scope discipline

Build the section that was asked for. Note what you found that wasn't in scope — a broken
link, a heading that reads wrong, a component gap — and let the decision be made rather than
absorbing it into this piece of work.

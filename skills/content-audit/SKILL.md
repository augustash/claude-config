---
name: content-audit
description: Audit and reduce a legacy CMS's content before migrating it — decide keep/move/consolidate/eliminate per node, find nodes that say the same thing in different words, and restructure the survivors into the new site's IA. Use when asked to audit content, reduce/prune content before a migration, plan an information architecture from legacy pages, find duplicate or overlapping content, decide what actually migrates, or when working in a content-audit doc or an overlap-sweep script. NOT for writing the migration itself (the Drupal migrate plugins/YAML) — this is the editorial pass that decides what those migrations get pointed at.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Content audit — reducing legacy content before it migrates

**The job:** a legacy site has N pages; the new site should have far fewer, better ones.
This is the editorial pass that decides which, and what shape they take. It runs **before**
the migration is written — migrate first and prune later and you build migrations for
content that gets deleted, then inherit the old site's IA by default.

Tool that ships with this skill:
[`templates/content-overlap-sweep.py`](../../templates/content-overlap-sweep.py) — copy to
`scripts/content-overlap-sweep.py` in the project and fill in its CONFIG block.

## The core insight

**A per-node pass cannot see the failure mode that costs the most.** Deciding "keep or
drop?" one node at a time is necessary, and it is structurally blind to *two nodes carrying
the same information wearing different clothes*. Migrate those as separate pages and you
replicate the old site's disorder forward, split SEO authority between competing
near-duplicates, and leave each page implying the other case doesn't apply.

So the audit is two passes, and the second is the one people skip.

## Pass 1 — disposition per node

Work node type by node type, published only unless the owner says otherwise. Assign each
node one of four:

| | Meaning |
|---|---|
| **KEEP** | migrates as a real page |
| **MOVE** | belongs in a different content type, section, or system |
| **CONSOLIDATE** | merges into a shared home with others |
| **ELIMINATE** | drops — superseded, stub, or handled by a system/feature |

Confirm one guiding rule with the owner up front — usually **old / superseded →
eliminate**. That single agreement converts dozens of individual judgement calls into one.

**Glance at the body of every eliminate candidate.** Title and length lie in both
directions. A "NULL body" flag is often the wrong field, not an empty node — check every
body-ish field before concluding a set is empty.

**Record a one-line reason per node.** The reason is what makes the call reviewable in six
months, and reversible when it's wrong.

**Watch for content that is really a system.** Confirmation pages, "no results" pages and
form-landing stubs are features of the new stack (Webform confirmations, search), not pages.
Same for a doc-index page whose entire content is a link list — the *files* matter, the
*page* doesn't.

**Salvage before deleting.** A page marked eliminate can still hold one paragraph worth
moving somewhere real. Note it on the row (`⚠ salvage brand-history paragraph → About Us`)
or it's gone.

## Pass 2 — the overlap sweep

Run the sweep **before building any section, not after.** Verbatim sentence reuse is the
tell and it needs no judgement call: a writer who copies three sentences between two pages
was usually writing one page twice.

```bash
python3 scripts/content-overlap-sweep.py --preset howto
python3 scripts/content-overlap-sweep.py 1372 1375 1376 139
python3 scripts/content-overlap-sweep.py --preset troubleshooting --boilerplate 99
```

Name the presets after the destination sections you're considering — the sweep's real
question is *"is this proposed section actually one topic?"*

### The four traps

These each cost a wrong call once. They are most of why this skill exists.

**1. The score is a candidate detector, not a verdict — always read the shared sentences.**
It fails in *both* directions:

- *False merge.* Two how-to pages scored 44%. All four shared sentences were boilerplate;
  underneath, they documented **different menu systems on different devices**. Merging would
  have produced one procedure matching neither — worse than shipping two pages.
- *False split.* A general troubleshooting page scored 46% against a blink-code page and
  read as mergeable. Decoding it row by row reversed it: only 5 of its 20 cause/fix pairs
  overlapped, and the other 15 served the reader whose device shows **no code at all** — a
  reader otherwise unserved by the entire section.

**2. Boilerplate inflates the score.** House furniture ("refer to your owner's manual") is
not evidence that two pages are the same page. The sweep discounts any sentence appearing on
3+ nodes, removing it from both the intersection and the denominator.

It's a dial (`--boilerplate N`), not a constant, because clusters want opposite settings: on
a set of *unrelated* pages a thrice-repeated sentence is noise, but on a set that is
genuinely **one topic in many variants** that same sentence *is* the duplication you're
hunting. `--boilerplate 99` disables it — also how you reproduce numbers recorded before the
discount existed.

Bonus: the discounted list the run prints **is** the section-level note to write once, in
place of repeating it on every page.

**3. A small denominator inflates the score.** Scoring against the smaller node is correct —
a short page wholly absorbed by a long one is the strongest possible signal — but it means a
24-sentence page scores high against almost anything. Check the sentence *count* before
believing the percentage.

**4. The sweep only sees the legacy CMS.** A legacy node duplicating content that **already
migrated** into the new site — a catalog product, a built feature, an existing component —
is invisible to it. One node scored a clean 20% against its own cluster and turned out to be
a product overview already owned by two live commerce products.

> **Before building any section, check its nodes against already-migrated content by hand.**
> Not automatable with this tool, and the trap most likely to ship.

### Group vs. merge — the distinction that decides everything

Two pages can share a *goal* without sharing *substance*. Only shared substance merges.

| Relationship | Example | Action |
|---|---|---|
| Same content, two presentations | one fault set shown as text codes and as LED blink counts | **merge** — write the prose once, keep both lookup paths, link them |
| Same goal, different substance | set up one accessory via two devices' different menu trees | **group** — one section, separate procedures, nothing deleted |
| Different content entirely | a second product line's troubleshooting, 0% overlap | **leave separate** |

The test: strip the boilerplate and the goal statement. Is what remains the same
information? If yes, merge. If it's two different sets of steps, group.

## Pass 3 — restructure the survivors

Reduction is half the value; the survivors need an IA the legacy site didn't have.

**Route by what the reader actually has.** The strongest organizing axis is the thing in the
reader's hand or on their screen — a fault message, a blink count, a symptom, a device
model — not the taxonomy the old site happened to use. Where one body of knowledge has
several entry points, keep every entry point (each is a real lookup path) and write the
substance **once**, with the entry points linking into it.

**Consult the legacy menus.** Comparing the old nav trees is the cross-reference audit's
payoff: duplicate clusters (two "Applications" items, three product trees) are direct
evidence for consolidation, and a legacy hub's link list is a ready-made checklist of what
must not go dark.

**New-component radar.** Note when a section needs a component the new site doesn't have,
and flag it explicitly (`⚠ NEW COMPONENT`) rather than quietly designing around the gap.
Check first whether an existing component already absorbed the job — on the reference
project a proposed variant was dropped once the base component gained the capability.

**Don't let content go dark.** Before deleting an index page, verify the files it pointed at
are covered elsewhere. Before dropping a listing, check nothing links to the items it
listed — an item with no listing migrates to a URL nothing reaches, which is how content
goes stale in public.

**A page whose only content is an embed is invisible** to search and to AI retrieval. If the
legacy page wrapped a video, keep its prose beside the video.

## Recording the decisions

The audit document is a deliverable, not notes. A future session picks it up with no memory
of the reasoning, so:

- **A `▶ RESUME HERE` block at the top**, rewritten each session: what's built, what's next,
  the specific next action, environment gotchas. This is what makes a cold restart cheap.
- **Record the *why*, not just the verdict.** "Eliminate" is worthless later; "eliminate —
  product overview already carried by catalog products 118/124, same generator list" is
  auditable.
- **Strike through reversals, don't delete them.** `~~One topic, two devices~~ **Wrong —
  reversed by the hand decode**`, plus the reason. A reversed call that silently vanishes
  gets re-made by the next reader of the raw data.
- **Close threads explicitly.** When the owner scopes something out, write it down once so
  it isn't re-investigated.
- **Fix contradictions upstream in the same pass.** When a decode changes a call, update the
  disposition tables and summary lists too, or the document starts disagreeing with itself.

## Building sections

Sections may be composed in code rather than clicked together, because a 22-row table is
easier to get right and to review as a diff, and a verify pass can assert the result
(anchors present, row counts per table, cross-links resolving).

**Such builders are scaffolding, not a source of truth.** The content rides up with the
database, and the moment anyone edits the page in the page builder a re-run silently
discards their work. **Retire them at handoff** — the DB carries the content by then, and
the audit doc remains the record of what was decided and why.

A composed section is a **construction, not a migration**: legacy tables get re-typed as
real data, `1. … <br> 2. …` prose becomes ordered lists, repeated boilerplate is stated
once, and dead outbound links are re-pointed at the new site.

## Scope discipline

Legacy sites are full of interesting rabbit holes.

- **Unpublished content:** look once, report what's there, let the owner scope it. Don't
  assume "unpublished = draft = ignore" (a complete, coherent series can be sitting
  unpublished), and don't assume it's in scope either. Ask once, then honour the answer.
- **Surface, don't expand.** When a finding implies work beyond the current section, write
  it into the doc and keep going. The audit's job is decisions, not doing every one.

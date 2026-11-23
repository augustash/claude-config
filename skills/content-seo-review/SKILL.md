---
name: content-seo-review
description: Review and rewrite a page's copy so search and AI answer engines read it right — headings that match their sections, sections that stand alone when quoted, the searcher's words over the house's, specifics over adjectives, one intent per page — and measure whether the edit moved citations. Use when a page is cited less than it should be, when ai-visibility shows a page "crawled, not chosen", when writing or migrating copy that has to be found, or in a POM+ search pass that reaches the copy itself. NOT for crawlability, schema or off-site work (ai-visibility owns those), NOT for heading structure as accessibility (accessibility-audit), and NOT for deciding which content survives a migration (content-audit).
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Content review for search and answer engines

**The job:** read a page the way a retrieval engine does, find where the copy fails that
reader, rewrite it, and check a few weeks later whether it got cited more. The tool is
[templates/content-seo-review/review.py](../../templates/content-seo-review/review.py)
(stdlib Python; its `blind` mode borrows ai-visibility's keys).

## Search hasn't died. The click has.

Answer engines don't replace search, they sit on top of it. For anything a buyer asks, the
engine runs a search (ChatGPT search leans on Bing, AI Overviews and Gemini on Google), reads
the top results, and writes its answer from those. A page that doesn't rank never reaches the
model. Crawlability, authority, titles and canonicals are still the base. What has changed
is what happens after the search, and that is what this skill writes for:

| Classic SEO thought | What the engine actually does now |
|---|---|
| The page ranks | A **section** is pulled out and quoted |
| Match the keyword | Answer the question as the searcher asked it |
| Win the click | Be **cited** or named in an answer the reader may never click past |
| Persuade the visitor | Give a model facts it can repeat without hedging |

Write once, for that reader. Copy that serves the extraction step serves classic search too,
so this skill keeps no separate keyword checklist. Revise the table as evidence comes in (see
*Grow with the metric*).

## How this joins ai-visibility

Two skills, one loop. **ai-visibility measures** whether the brand is named and the site
cited. **This skill edits** the pages. Where they overlap, the overlap is shared, not copied:

- **Input.** ai-visibility's crawl check marks a page *crawled, not chosen* (✓s across the
  row but the answers don't move), and its query set shows which questions the site loses.
  Those are this skill's queue, ahead of anyone's hunch about which pages are weak.
- **Shared log.** Every edit made here goes in ai-visibility's `changelog.md` (date, page,
  what changed, which queries it targets) and gets a row in `watch.json`. That is the only
  way a later round can attribute movement to the edit.
- **Outcome.** `run.py pages` counts the answers citing each page, this round against the
  last. That number, for the queries the edit targeted, is how the edit is judged.
- **Keys.** `review.py blind` uses the client's ai-visibility key file and the OpenAI model
  pinned in `queries.json`. There is no second secrets path.

On a site without ai-visibility set up, the review still runs (`extract` needs nothing), but
there is nothing to measure against. Say so in the write-up, and recommend setting it up first.

## The review

```
python3 vendor/augustash/claude-config/templates/content-seo-review/review.py extract <url> [<url>…]
python3 vendor/augustash/claude-config/templates/content-seo-review/review.py blind <url> --ai-dir docs/seo/ai-visibility
```

`extract` prints title, H1, description, canonical, JSON-LD types and an outline of the page
cut at its headings: word count per section, how many of the heading's words appear in its
body, and mechanical flags. `blind` additionally sends each section's **body without its
heading** to a model acting as the retrieval step. The model returns the question the section
answers, a heading it would write, and whether the section stands alone. Run `extract` against
the local site while editing; run `blind` once before and once after, so the comparison is
like for like. `--json` saves a snapshot to diff.

The flags are prompts to look, not findings. Every claim that goes into a write-up has been
read in the page itself.

### 1. Does each heading say what its section does?

The heading is the label the engine files the section under. Compare it to the blind heading
and blind question. When they disagree, ask whether the heading is wrong (rename it) or the
body wanders (cut it or split it). `generic heading` (Overview, Features, Specifications) names
a slot in the template, not the content. "N Series Overview" tells the engine nothing that
"800–4800 W pure sine inverters for 12 and 24 V systems" doesn't say better.

**A spec table is the exception.** A heading like *DC Input* over a table of battery voltages
scores zero overlap and is correct. Tables are data. Judge them on whether the row and column
labels carry units and the searcher's words, not on overlap.

**The heading may be the anchor.** On Neo sites the `id` is derived from the title, so a rename
moves the anchor (see
[neo-alchemist-heading-anchor-override](../../memory/augustash/neo-alchemist-heading-anchor-override.md)).
Search for inbound links to the old anchor before renaming.

### 2. Does each section stand alone?

An engine quotes a section, not the page. `opens on a back-reference` (This, These, It, As
mentioned) means the first sentence needs the section before it. A blind result of
`standalone: false` names what is missing. Fix it by **putting the subject in the first
sentence, and the answer before the explanation**. "It handles up to 4800 W" becomes "The N
Series handles up to 4800 W." Facts that exist only in an image, a PDF or a tab hidden from the
server HTML don't exist for this reader.

### 3. Is it written in the searcher's words?

The house's term for a thing is often not the buyer's. "Locator" is the industry's name for the
widget, not a phrase anyone types (see
[traffic-count-is-not-a-search-signal](../../memory/preferences/traffic-count-is-not-a-search-signal.md)).
Where the two differ, the searcher's word goes in the heading and first sentence, and the house
term can follow once. The evidence for which word searchers use is query data: Search Console
queries the page gets impressions for, and ai-visibility's technical queries. When neither
exists, say the wording is a judgment, not a finding.

**Search Console's best find** is a query the page is shown for (impressions) but rarely
clicked: the engine thinks the page is relevant, but the copy doesn't answer it. That gap
is usually a missing section, not a reworded one.

### 4. Specifics over adjectives

Engines repeat what they can attribute: numbers, units, standards, certifications, places,
named models. "Rugged, reliable power" gives a model nothing to cite. "Rated −40 to 60 °C,
UL 458 listed, 5-year warranty" does. Visible text should state the same facts as the page's
schema. A spec only in JSON-LD is half-stated, and a spec only in prose can't be read by a
machine.

### 5. One page, one intent

Title, H1 and meta description should say the same thing as the body. `title and H1 share no
words` is usually a template default, not a decision. Two pages answering the same question
split citations between them. Check suspected overlap with content-audit's
[content-overlap-sweep](../../templates/content-overlap-sweep.py) before writing a third.

**Never write a page per market or per query.** That is a doorway page, and Google penalizes it
as scaled content abuse (ai-visibility explains why). A missing answer goes into the page that
owns the subject.

## Writing the change

Show the rewrite next to the original, section by section, with the finding each change
answers. Copy follows the client's English
([us-spelling-in-client-copy](../../memory/preferences/us-spelling-in-client-copy.md)).
Facts come from the client's own sources: never invent a spec to make a section concrete. Mark
a gap as a question for the client instead.

When it ships: changelog row, `watch.json` row, and a `--json` snapshot of `blind` filed under
`docs/seo/content-review/<date>-<slug>.json` so the after-run has something to compare against.

## Grow with the metric

This skill is a set of bets about what engines reward, and the bets will change. Grade them
with the numbers instead of defending them:

- **Leading indicator (days):** blind agreement. The share of sections where the blind heading
  and question match the real heading, before and after. It moves as soon as the copy does and
  says nothing about citations yet.
- **Crawl (1–2 weeks):** the watched page re-fetched by each engine (`crawl.py`). No re-fetch
  means no verdict yet. Push it with IndexNow or Search Console instead of rewriting again.
- **Outcome (2–6 weeks):** `run.py pages`, answers citing the page, for the queries the edit
  targeted. Read it like the main report: a move under two standard errors is noise, and act
  on a trend over rounds, not a single round.

After each graded edit, add a line to the ledger below: what was bet, what moved. A check that
keeps producing edits that don't move citations gets demoted or rewritten. A pattern that keeps
moving them gets promoted into the review. The measurement only works if rounds keep running.
A lapsed cadence leaves every edit since the last round ungradeable.

## Signal ledger

What this skill believes, how strongly, and why. Update in place.

| Signal | Confidence | Evidence |
|---|---|---|
| Engines cite sections, not pages; a standalone answer-first passage beats one that leans on context | High (mechanism) | How retrieval-augmented answers are built; engines cite with fragment anchors to passages |
| Off-site sources outweigh on-page copy for generic "best X" queries | High | ai-visibility baseline, DMX 2026-10-28 |
| On DMX, site citations came almost entirely from branded queries; technical queries rarely cited a DMX page | Observed, baseline | `run.py pages` on 2026-10-28 — the case for this skill |
| Spec facts in visible text and in schema together beat either alone | Medium | Bet; first graded edit pending |

## Corrections log

- 2026-11-23 (DMX): `review.py` first skipped every `<header>`, including the one inside
  `<main>` that holds the H1, and reported "0 H1s" on pages that had one. A header or footer
  inside main belongs to the page. The fix keeps them.
- 2026-11-23 (DMX): ai-visibility rounds lapsed for four weeks after eleven shipped changes,
  leaving none of them gradeable. Measuring is part of the edit, not a follow-up.

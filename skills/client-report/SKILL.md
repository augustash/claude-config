---
name: client-report
description: Build an evidence-led client report or rebuild pitch — gather real data, frame it so it sells without overclaiming, and ship it as a self-contained branded HTML page. Use for rebuild bids, site audits, discovery findings, value summaries, or any document where we tell a client what we found and what we would do about it.
---

# Client report

A method for producing the document we hand a client when we want them to
understand what we found and buy what we would do next. Refined on the DMX Power
rebuild report and the MSP Airport rebuild briefing.

Two outputs, always:

- **`<report>.html`** — self-contained, branded, opens by double-click, zips for email.
- **`<report>.md`** — same content, plain. Easier to edit, diff and reuse.

Optionally a third: **`technical-appendix.md`** — the depth the presenter consults
when someone digs. Keep it out of the client document.

---

## 1. Evidence before argument

Never write a finding you have not measured. The credibility of the whole document
rests on the reader trusting the numbers, and one soft claim taints the rest.

**Sources worth pulling, roughly in order of value:**

| Source | Gives you |
|---|---|
| Origin access logs (nginx) | Feature-level demand, 404s, bot share, third-party consumers, search terms |
| The content database | Real counts — published vs. unpublished, field usage, dead models |
| Config export | Content types, fields, views, indexes, integrations, duplication |
| **Replaying real queries against the live system** | The single highest-value move — see below |
| GA4 / analytics | Per-page popularity, which logs behind a CDN cannot give you |

**Replay real user behaviour against the real system.** Pull the top N search terms
out of the logs, run them against the site's actual index, and record what comes
back. On MSP this turned "search feels bad" into *only 8.7% of real searches return
a usable result; 37% return 151+ results on a 1,069-item site.* That number carried
the entire document. The same move generalises: take what users actually did, feed
it to the thing that serves them, measure the outcome.

**State what the evidence cannot support.** Origin logs sit behind the CDN, so they
measure *load*, not popularity — a well-cached page barely appears. Say so in the
document. On MSP, an attempt to rank content pages this way produced an obviously
bogus distribution (every page in one narrow band = crawler traffic, plus alias
collisions inflating a node with the flights board's 129k hits). The right response
was a caveat box saying per-page popularity needs GA4, not a quiet fudge.

**Verify before you claim.** Specific traps that have bitten:

- **Author-name variants in git.** `kazajhodo` (2018) and `KazaJhodo` (2020) are the
  same person; querying one gave a takeover date two years late. Always
  `git log --format="%an" | sort -u` first.
- **Alias collisions.** One alias mapping to six language rows attributed a
  high-traffic page's hits to a content page. Print top matches before trusting a join.
- **Assuming current state.** A remap that read the existing state wrong was a silent
  no-op. Print the before-state, transform, print the after-state.
- Config-file semantics — e.g. Drupal's `core.extension.yml` lists *enabled* modules
  with their **weight**; `scheduler: 0` means enabled, not disabled.
- **Your own notes go stale, and they are the source you trust least carefully.** A
  build doc said the catalog went "129 → 192 variations"; the database said 186, and
  no legacy count matched 129 either — it had been comparing two states of our own
  work. A tracking note carried a feature as "in progress" that had shipped weeks
  before. A feature was written off as unbuilt because the check only scanned page
  component trees, and it was served by its own route. **Re-query the running system
  for every number and every status at the moment you write it**, and prefer a query
  that would fail loudly over one that returns an empty set.

---

## 2. Framing — the rules that make it sell without lying

**Judge every recommendation twice.** What it does for *their* users, and what it
gives *them* to manage with. Those are the same investment: a site that's hard to
maintain quietly limits what the client can offer. State the pairing explicitly up
top; it turns foundation work from a cost into a capability.

**Age is context, not fault.** For a long-standing client especially, never let the
document imply neglect — theirs or ours. One paragraph near the top does this for
every finding at once:

> This site was built when [framework/era] was new, and it was built well for that
> moment — the choices in it were the standard, sensible ones at the time. What
> follows is not a list of mistakes. **The gap is between what was right then and
> what is possible now.**

Then police the vocabulary. "Move to a *proper* search engine" implies the current
one is improper — i.e. someone erred. "Move the index to a *dedicated* search
service" says the same thing and blames no one.

**Every weakness carries two answers.** Where we've held the account a while, a bare
problem list reads as an indictment of us. Pair each one:

- **Why this is still here** — the honest mechanism. It never errored. It lived in
  logs nobody reads. It was blocked on a contract. It wasn't incrementally fixable.
  *The runway went to stability first, correctly.*
- **What we would do** — the move, with enough specificity to be credible and a way
  to prove it worked.

**Never speculate about why something wasn't done.** The *why it persists* half is
where a document quietly insults the people reading it. You do not know their budget
cycles, their priorities, or what was already on their roadmap — so say so, credit
that it may well already be on their list, and speak only to what you *can* observe:
what the system itself made difficult. Name real constraints (an older foundation's
limits, licence terms, work that can't be absorbed by a maintenance pass) rather than
implying a lapse.

Two habits that catch it:

- **Negating a word still plants it.** "This was never a small fix that got skipped"
  puts *skipped* in the reader's head. Cut the word, don't deny it.
- **Don't distance us at their expense.** "Inherited from the original build, not
  authored by us" defends us by indicting whoever built it — possibly someone still
  in the room who commissioned it. "The accumulated weight of a foundation laid a
  decade ago, under the assumptions and budgets of its time" states the same fact
  with no defendant.

Also check you haven't *understated* their work. Claiming a filter "only offers
Terminal 1" when their content team tagged 400 records to concourse level is the same
category of error, pointed the other way — and the person who did that tagging will
be reading.

**Convert observations into moves.** Any sentence that states a gap and stops is a
wasted opportunity. "There is no search reporting" → "a standing search-quality
report tells your teams, in your customers' own words, what people came looking for
and did not find." Watch for these on every pass.

**Check what the client already owns before recommending a build.** The strongest
findings are usually *capability already paid for and not connected* — a licensed
platform the site never calls, data already synced but never displayed, a metric
already calculated and sent to analytics instead of to users. These are cheap,
credible and flattering to propose.

**Lead the questions with the generative one.** Ask what data, APIs and systems they
already have access to *before* the scoping questions. It changes what's possible,
not just what's affordable — and it routinely surfaces assets nobody remembered.

**Never assert what the client knows to be false.** If they say a claim is wrong,
pull it immediately and replace it with the defensible version, even if the wrong
version was stronger. One bad claim in the room costs the whole document.

---

## 3. Weighting — what earns space, and in what order

**A win's weight is the achievement multiplied by the surface it lands on.** This is
the rule the rest of the section follows from. A neat fix on the privacy policy is a
small win however clever it was: the page is minor, rarely read and boring. Sitewide
data integrity that makes accurate faceted search possible is a huge win, because the
surface is the entire catalog. Rank by that product — never by how hard the work felt
or how long it took, which is the ordering that comes naturally and is always wrong.

**Order the list the way the client's own site is organised.** The main menu is
usually the best available proxy, because it already encodes what they consider
primary: products before support before a single tool. Following it also means the
document and the site teach the same shape, so a reader never has to translate.

**Where hierarchy and weight disagree, weight wins.** A sitewide structural change
outranks a single page even when that page sits higher in the menu. On DMX, "pages
are built from components rather than raw HTML" had been filed last; it applies to
every page and every editor permanently, so it belonged above three single-page
groups.

**Group by section, not by theme.** A thematic group cuts across the hierarchy and
breaks the pattern everything else follows. On DMX a "Protected by default" group
looked tidy and held three items that belonged in three different places — a gated
library that lives on the support page, decoy addresses that are a locator feature,
and a cookie decline that is neither. Dissolving it into the section groups made all
three easier to place *and* forced two thin groups to earn a real second item.

**Test every candidate: does it permanently change what the client can do?** Durable
capability beats one-time repair. Applied strictly this cuts more than expected —
hygiene work that saves cost but changes no behaviour, and any insight billed twice
under two headings. Cut both; a padded list devalues the items that earn their place.

**Tell their journey, not ours.** The client wants the story of their site going from
a malformed mess to integrity and polish. They do not want the story of us building
and repairing our own work. **Fixing the legacy data is the win; fixing a bug in our
own migration is not** — it is invisible to them, it is not what they are buying, and
it plants a doubt in a document whose whole job is confidence. The same cut applies
to any credential, defect or near-miss on our side that never reached production:
disclosing it reads as honesty to us and as alarm to them.

**Never claim a capability that is not live yet.** On DMX the catalog band was titled
"a catalog that can sell" and led with "every build is orderable" — while cart and
checkout were switched off. The honest framing was stronger anyway: their product
*content* became structured products. State what is true today; put the rest in the
futures section where it is correctly scoped as not-yet.

---

## 4. Structure that has worked twice

Numbered sections, stable IDs, scannable. Roughly 200–250 lines of markdown; the
temptation is always to over-write.

1. **Masthead** — the lens (who it's for, how it's judged), the era framing, and the
   standard being aimed at. Keep to three short paragraphs plus an evidence strip.
2. **The five things that matter** — the whole argument, scannable, with numbers.
   *Each one paired with our response,* or it reads as an indictment.
3. **How it's used** — one table, ranked, plus the readings that change the picture
   (what looks small but isn't, what looks huge but is cached).
4. **What's working** — assets to protect. Name them. This buys credibility for the
   criticism that follows and gives the rebuild something to preserve.
5. **Opportunities** — *not* "Where it falls short". Same content, and every item
   carries its why-still-here and what-we'd-do.
6. **The moves** — grouped by outcome, each stated twice (user benefit + engineering),
   with effort. Close with a short **where we'd start** sequence: contract answers
   first at no cost, then fast visible wins, then foundation, then differentiators.
7. **What we already have** — the inventory of their own data and integrations, and
   what combining them unlocks. Sets up the questions.
8. **What we need from you** — questions, generative one first.
9. **Why this team** — a specific, dated, verifiable story. See below.
10. **Why this is the moment** — close on possibility, built only from findings
    already established above.

**The credibility story.** One concrete incident beats any amount of positioning.
The MSP version: inherited 2018, crashing weekly, deployments themselves taking it
down so the client feared deploying; two prior teams paid two weeks each, neither
found it; nobody told us; we pulled the database, saw millions of duplicate rows,
traced it to a malformed cache tag whose second half resolved to a new unique value
every request — *the site was simultaneously caching nothing and storing everything*;
resolved in about two hours.

Mine the repo for **receipts** — first commit date and message, a tellingly-named
branch, a one-line diff. Verifiable beats impressive. But if the client says your
receipt is the wrong one, drop it and keep the story; the mechanism is the point.

---

## 5. Design

Load the `frontend-design` skill first. Then:

**Self-contained or it isn't deliverable.** No external fonts, scripts, images or
CSS — it must open offline, on a locked-down laptop, from a zip. Verify:
`re.findall(r'(?:src|href)="(?!#)([^"]+)"', html)` returns empty.

**System fonts only, and let mono carry the personality.** Every figure in
`ui-monospace` with `font-variant-numeric: tabular-nums` — columns align, numbers
scan, and it needs no download. Heavy tight-tracked system sans for headlines.

**Pull brand colors from the client's own source, never from memory or a logo.**
Their theme's variables file is authoritative and usually contains a semantic system
worth reusing. Watch for a "current" brand token that differs from the one used
everywhere in practice — flag it rather than silently picking.

**Find the signature in the client's own world.** Not a big number with a gradient.
For an airport: the departure board — the exec summary rendered as status rows
(`SEARCH · CRITICAL`, `WAYFINDING · NOT CONNECTED`, `FLIGHTS BOARD · ON TIME`). It's
their instrument turned on their website, and it's the fastest possible read of five
findings. Spend boldness once, then go quiet.

**Make structural devices mean something.** Cycling section colors by position is
decoration. Assign them: one hue for evidence, one for opportunity, one for the
single genuinely-bad section — used *once*, so it lands. Watch for color fighting
copy: red under a collaborative "what we need from you" section reads as danger.

### Working colour with a client, without ping-pong

This is where the most time gets burned. The lesson: **stop nudging hex values and
define the system.**

- **Work perceptually, not in sRGB.** Equal sRGB steps do not read as equal
  lightness — gold at the same nominal value looks far lighter than blue, so the
  sections never feel like siblings. Derive grounds in OKLCH at one lightness with
  only hue varying, then convert to hex.
- **Separate the two knobs and name them.** *Overall lightness* (how deep the ground
  sits) and *delta* (how visible the gradient is) are independent. Changing one
  while chasing feedback about the other is what causes the loop.
- **Learn their gradient vocabulary.** "Dark bottom, subtly lighter top, light
  favouring the top edge, mostly the darker" is a spec about **proportion**, not
  lightness: settle the ramp by ~20% of section height so four-fifths is the settled
  tone. `0deg` in CSS means bottom-to-top.
- **Run contrast before committing.** White on `#ffad1f` is 1.87:1 — unreadable. Give
  the numbers and offer the fix (deepen the ground, don't lighten the text) rather
  than shipping it or silently refusing.
- **Build a palette page.** A one-off `palette.html` with real chips, hex, variable
  names and live gradient swatches lets the client point instead of describe. Worth
  the ten minutes every time.

**Label with strong verbs.** Section and block labels are the most-read words in the
document — keep them short and active. *Action*, *Focus*, *Next*, *Plan*, *Improve*,
*Capability* beat *What we would do*, *The five things that matter*, *Engineering and
compliance*. A long label reads as hedging; a one-word label reads as command of the
material. Pair a diagnostic label with an active one — **Why it persists / Action** —
so every problem visibly resolves.

**Cut copy that explains its own structure.** The most common source of clunk. "Each
is stated twice — what it does for X, and what it gives Y — because that second part
is what makes the first durable" spends its closing clause defending a layout choice.
Replace the explanation with a claim: *"once for the people using the airport, once
for the team who has to run it. A gain nobody can maintain isn't a gain."* Same point,
and it's a sentence someone repeats in a meeting. Whenever a paragraph ends by
justifying its own format, that's the sentence to rewrite.

**Sprinkle fun, sparingly and on purpose.** The document is serious, but people like
fun, and fun makes a thing not feel like work — which is worth real money in a room.
A pun in a section title, one dry aside, a heading that carries a double meaning from
the client's own world (*Traffic patterns* for a usage section; *Final approach* for a
closing). Rules that keep it from curdling:

- Put the humour where the finding is *already* absurd — 99 people searching for a
  terminal that doesn't exist writes its own joke. Don't manufacture one.
- Land the laugh, then immediately convert it to the fix, so it earns its place.
- Never in the sections carrying bad news, the credibility story, or the asks. A
  wink next to "your site was crashing" or "we need your contract terms" reads as
  flippant.
- Two or three per document. It's seasoning, not a flavour.

**Typography and rhythm.** One idea per paragraph — long slabs are the most common
complaint and the easiest fix. Content panels (tables, cards) on a translucent white
fill lift off any coloured ground. Keep one reusable divider token so the whole
document changes at once.

**Tokenise the panel system early.** Tables, cards and callouts are the same shape
doing the same job — one `--panel-pad` and `--panel-radius` keeps them consistent and
makes "more padding on these" a one-line change instead of three. The same applies to
the divider: one gradient token, used everywhere, changes the whole document at once.

**Retreat components into their section's colour family.** A card sitting on a
coloured ground inherits the document's default ink and instantly looks foreign. Give
it a *ramp* in the section's own hue — number, heading, body, aside at three or four
weights of one colour — rather than a single flat tone. That's what makes a panel look
designed into its surroundings instead of dropped onto them.

**A long report wants a sticky section nav.** Anchor every section, put the bar under
the masthead rule, mark the active one with `IntersectionObserver`, give sections
`scroll-margin-top`, hide it in print. Use an opaque ground — a translucent bar shifts
colour as it passes over differently-coloured sections.

**Quality floor, unannounced:** responsive, keyboard focus visible, reduced motion
respected, and a print stylesheet that flips dark bands to white.

---

## 6. Delivery

- `open` the file after every change so they're reviewing the current state.
- Keep the markdown in sync with the HTML on every edit, or it rots within an hour —
  and **verify both after every structural edit**. On MSP the markdown silently kept
  a question the HTML had dropped, because one regex matched and the other didn't.
- Split depth into `technical-appendix.md` rather than cutting it — the presenting
  dev needs it even though the client shouldn't see it.
- **Ship a folder, not a loose file.** Zip a directory containing the HTML (named
  readably, spaces are fine), the markdown source, the appendix, and a short
  `README.txt` saying what each file is and what the evidence base was. It survives
  being forwarded to someone who wasn't in the conversation.

**Run an integrity check before packaging.** Cheap, and it has caught real breakage:
no external `src`/`href`, balanced CSS braces, balanced `<div>`/`<section>` counts,
no rules with a missing selector, every nav anchor resolving to an existing id.

## 7. Working with the reviewer

Expect fast, terse, mid-turn corrections. Apply, verify by printing the result, and
reopen.

**Take the note, then generalise it.** Being handed exact pixel values means the
pattern hasn't been learned yet — treat each one as a symptom of a rule that should
already have been inferred. When told "`h5` to 12px", also pull the letter-spacing
back (tracking that reads open at 9px shouts at 12px) and raise the panel's padding
so the proportions still hold. When told to fix one divider, fix its sibling in the
other component. Apply the change *and* the system it implies, then say what you
extended and why so it can be corrected in one word.

**Propose systems, not values.** "Which hex?" is a worse question than "here are
three grounds at matched perceptual lightness — too heavy or about right?" Do the
arithmetic (contrast ratios, OKLCH conversions, ramp derivations) rather than asking
the reviewer to eyeball it; bring the numbers to the decision.

Two habits that matter:

- **Print the state after every structural edit.** Renumbering, remapping and
  reordering all failed silently at least once on MSP; only verification caught it.
  Removing a block leaves unbalanced tags just as easily — count them afterwards.
- **Scope regex edits to a section.** A renumber intended for one list rewrote the
  numbered summary at the top of the document. Slice the section, transform, splice
  it back.
- **Anchor CSS edits on unique strings.** Inserting before `.move .eng span{` spliced
  into the *middle* of `.sec--gold .move .eng span{`, leaving an orphaned global rule
  the base rule then overrode — which surfaced days later as "that colour is off".
  Include enough of the selector, or the preceding line, to be unambiguous.
- **Use absolute `git -C <path>` in nested repos.** A failed `cd` sent a commit
  intended for the shared-config vendor copy into the *project* repo, sweeping up
  unrelated work under the wrong message. Never rely on the shell's current
  directory when two git repos are in play.

**When they say a section repeats, they're usually right.** The *what we'd do* blocks
and the moves list both answer "what would you do", so they drift into duplication
naturally. Fix it by deciding which one owns the argument — usually the moves, since
they carry the value framing — and reducing the other to a pointer.

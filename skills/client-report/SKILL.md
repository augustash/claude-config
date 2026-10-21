---
name: client-report
description: Build an evidence-led client report or rebuild pitch — gather real data, frame it so it sells without overclaiming, and ship it as a self-contained branded HTML page. Use for rebuild bids, site audits, discovery findings, value summaries, the monthly maintenance record every site-update round ends with, response documents answering a written request (legal demand, client questionnaire, post-incident), or any document where we tell a client what we found and what we would do about it. Owns our doc design system and components for every client doc. Not for internal or technical write-ups, and not when the finding is one the client would rather be told than sent — confirm a document is actually wanted before building one.
---

# Client report

A method for producing the document we hand a client when we want them to
understand what we found and buy what we would do next. Refined on the DMX Power
rebuild report and the MSP Airport rebuild briefing, and on the monthly maintenance
records (§6). Every client doc we build uses this skill's design system (§7).

**The goal is to help the client grow.** Their growth is what grows us, so we don't
need to aim at selling; we aim at making them better, and the work follows on its
own. Every doc carries ideas, and most are work we would do, but each one earns its
place by what it does for their business: grounded in their data, in their words,
measured against what their site is for. When a line reads as selling rather than
helping them grow, it's aimed wrong, so rewrite it toward what they gain (Kaza,
Meridian Display 2026-09-28).

The same holds for what we offer them to buy. An offer of little value to the client,
such as a higher maintenance plan their site doesn't need, helps us, not them, and it
shows eventually. Treat clients the way we would want to be treated (Kaza, cal
2026-10-19).

**No client doc goes out without a developer reviewing it, and the doc is the review.**
Build it complete, open it for the dev, and revise from their notes: take, cut, reword,
re-price. Don't walk the findings through one at a time first; that recap says what the
doc already says, and the dev reviews it better on the page, in the form the client will
read it. What has to happen before the doc is verification: every finding re-checked
against its evidence, and anything that becomes a Work row tested (Kaza, md 2026-10-19,
replacing the one-idea-at-a-time walkthrough set on cal the same day).

**The deliverable is one HTML file.** Self-contained, branded, opens by
double-click in any browser, zips for email. Clients open these in a browser —
they do not read markdown, and a parallel `<report>.md` twin is not wanted.
Don't produce one; it is a second copy to keep in sync for no reader.

Alongside it: **`technical-appendix.md`** — the depth the presenter consults when
someone digs. Internal, markdown is right for it, and it stays out of the client
document.

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

**Quote the steady baseline, not a spiky total.** A twelve-month count that includes a
spam wave overclaims. On Meridian, 850 form entries shrank to *about 33 a month since
February* once a four-month spike, most likely spam past the filter, was set aside. Break
every count down by month before using it. Check order figures for refunds (WooCommerce
`wc_get_orders` returns refunds unless you pass `type => shop_order`) and for
pass-through such as shipping, which was half of Meridian's online revenue.

**Verify before you claim.** Specific traps that have bitten:

- **Author-name variants in git.** `kazajhodo` (2018) and `KazaJhodo` (2020) are the
  same person; querying one gave a takeover date two years late. Always
  `git log --format="%an" | sort -u` first.
- **Alias collisions.** One alias mapping to six language rows attributed a
  high-traffic page's hits to a content page. Print top matches before trusting a join.
- **Data that reached us through a sync is not the client's data.** On wps a careers
  report was drafted around "seventeen postings on department names you've stopped using".
  The upstream Paylocity feed contained none of them — they were stale nodes our own sync
  had failed to remove, and the section was about to bill our bug as their naming problem.
  Pull the source feed and reconcile it against our copy before attributing anything to a
  client; the per-item deltas are the tell, and they summed to exactly the stale count.
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

**Show the complexity, as a worked example.** A client seeing the hard parts of their
own business laid out reads it as proof that we have thought about it. Simplifying them
away reads as not having looked. So the thinking goes into two places:

- **The project notes get the full model** (`.claude/memory/`): data shapes, edge cases,
  sequencing, what it costs and why. Write it while the detail is fresh, because it is
  the scoping document the sale will need.
- **The client gets a variation of it**, in their terms. One realistic case followed all
  the way through, with numbers that reconcile, beats a list of features. Then a short
  *what makes it work* list names the hard parts and what we would need from them.

On Meridian Display (2026-09-28) the rebuild pitch showed a single order: two artworks
of one display, split across two chains' stores and DCs, consolidated into six
shipments, one flagged late and switched to expedited. Label invented figures as
illustrative, and make them add up, because the reader will check. Kaza's direction:
*"it's good for clients to see complexity. It indicates we've really thought about
their business."*

**Their customers stay out of the document.** Form entries and orders name the
client's own customers, and naming one in a document that will be forwarded isn't
ours to do. Write the category instead: *brands putting product into grocers, club
stores and natural-food chains*, never the brand or the chain. Keep the names in
the project notes as the evidence behind the line.

**Use their industry's words, all the way through.** Borrow the terms their buyers
already use and hold them: on Meridian that was *retailer, store, distribution centre,
rollout, in-hands date, dieline*. The reader should recognise their own business,
not a web agency's description of it.

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

**Write what we propose in the conditional.** A pitch describes a system that doesn't
exist yet, and present tense quietly claims it does: *"their account keeps each
retailer's stores"* reads as a feature they already have. Use *would* and *should*
for everything we would build (*"their account should keep…"*, *"the invoice would
go out"*), and keep the present tense for what is true today (*"you already supply
dielines"*). Step labels in a flow strip can stay imperative, because they read as
a process rather than a claim (Kaza, Meridian Display 2026-09-28).

**Once the client has chosen the work, switch to *will*.** The conditional is for
work they haven't committed to yet. A plan for a project they've already asked for
(gif's move from Klaviyo to Pipedrive) talks about what we are going to do: *"what will
happen each time someone sends the form"*, *"we'll build and test against a sandbox"*.
Leaving *would* there makes agreed work sound optional (Kaza, gif 2026-10-20). An
option that's still genuinely open in the same doc, like a choice the client hasn't
made, can take the present (*"that's the natural replacement"*) instead.

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

## 5. When the document answers a request

Everything above assumes a pitch: we chose what to say. A **response document** is a
different genre — an accessibility record answering an ADA demand, an audit answering a
client's written questions, a post-incident report. The reader is holding the request
while they read. Most of the rules still apply; these are the ones that only apply here.

**Restate what was asked, and map it.** Open with the request itself — each part, and
where in the document it is answered. Without that, a reader cannot tick off their own
list, and a document that answers everything still reads as though it dodged something.
On sisal the record answered all three allegations and never once restated the five-part
request it was written for; adding that map was the single largest improvement to it.

**Read the source document, not a summary of it.** The sisal demand described its own
list of allegations as *"illustrative and not exhaustive."* The record answered the three
items as though three items were the ask — and had nothing to say about the framing. That
one clause changed how all the volunteered extra work should be presented: not diligence
beyond the request, but the request being answered as written. Ask for the original.

**Assume an adversarial reader even when the client is friendly.** The document will be
forwarded to counsel. Strip incidental technical attribution that widens the claim beyond
this site — a framework name and version in a header invites *"is the framework
inaccessible?"*, which is a bigger fight than the one being answered. Describe the
mechanism (`the framework could not construct a validation message`) and keep the name in
the internal appendix. The evidence loses nothing.

**Sweep for statements the world has falsified.** A response is written over days and
sent after them. "These corrections take effect only once deployed to production" was
true when drafted and false the hour the deploy landed — and it was the load-bearing
sentence of its section. Any sentence in the future tense about your own work is a
liability the moment that work happens; re-read them all whenever anything ships.

**Never assert something checkable about your own document without checking it.** A line
claiming each finding recorded all eight requested fields was written, then found to be
false for two of the three. An adversarial reader checks exactly these. Verify, then
write the claim that survives verification.

**State a status on every peer, or on none.** A summary table where one row ended
"Corrected" and the others ended without a status implied the others were not corrected —
when in truth one needed no correction and one had an improvement pending. Parallel rows
must answer parallel questions.

### Line editing — the cuts a developer will not make

A strong writer strips these by reflex. Everyone else leaves them in, because each one
feels careful. All of these were cut from a single document in one sitting:

- **Sentences about the document instead of in it.** *"It is restated here in condensed
  form, with a pointer to where each part is answered. The condensation is for navigation
  only; nothing was narrowed."* The table beneath it demonstrated all of that. Meta-text
  explaining your own structure is the most common filler in a technical document.
- **Pre-emptive hedges and scope carve-outs.** A block of stated limitations, and *"authenticated
  and administrative areas were out of scope by direction."* Defensible, and it reads as
  building an excuse before anyone has complained. Where a limitation genuinely qualifies a
  finding, put it *on that finding*, not in a list of everything that could be doubted.
- **Narration of what an artifact already shows.** Two screen-reader transcripts sat side by
  side, before and after; a paragraph then explained what they demonstrated. If the exhibit
  works, delete the caption.
- **Cross-reference links inside prose.** *"— see §4, item 1"* breaks the reading line to
  offer navigation nobody asked for. State the outcome. The exception is a finding whose fix
  lives in another section: that gets a link on its own line (§7, *a finding that needs
  action links to the item that acts on it*), never a pointer in the sentence.
- **Words carrying no load.** *"the auditing tools normally used"* → *"the auditing tools
  used"*.

The test for all of them: does the sentence say the thing, or talk about saying the thing?

---

## 6. The maintenance record

The third genre: the short record a client gets after every maintenance round. It is
not a pitch and not a response, though it can carry one of each: a held item the
client has to act on, and a Horizon when the round turns up a rebuild. The round
itself (updates, holds, verification) is [site-update](../site-update/SKILL.md)'s job;
the record is this skill's.


Every [site-update](../site-update/SKILL.md) round ends with one, not just the
blocked ones. The page written for atr existed because the client had to *act* on
a lapsed subscription, but the standing habit is one short record per round
regardless, so "what did you do to our site last month" has a file to point at.

**The HTML is sent; a Markdown summary is kept.**

- **To send:** `.claude/docs/pom/<Client> Website Maintenance - <Month Year>.html` in
  the project, **committed** (Kaza, cal 2026-10-19). It has a readable filename with
  spaces, because it gets attached to an email. A doc with companion files (screenshots,
  an appendix) gets a dated folder instead: `.claude/docs/pom/<YYYY.MM>/`. When the
  client sends back their approved copy, save it beside the original as
  `… - approved.html` and commit it, so the approvals are on record.

  **One record at a time: each round's replaces the last** (Kaza, atr 2026-10-21).
  Before drafting, read the record already in `.claude/docs/pom/`, since it shows where
  the site stood and what was promised. Carry forward what still applies: an open hold,
  a *Next* item not yet done, an idea still unanswered. Drop what the round closed. Then
  `git mv` the old file to the new month's name and write over it, so the folder never
  grows a pile of stale records and git history keeps every version. The approved copy
  goes the same way: once the next round's record is written, the old `… - approved.html`
  is removed.
- **To keep:** `.claude/memory/records/<round>.md` (for example `2026.09.md`),
  committed and indexed in the project's `MEMORY.md`. It holds:
  - what was updated
  - each held item, with the urgency and action the client was given
  - what *Next* promised
  - the idea (with its quote) and any Horizon pitch
  - what's still awaiting the client

  The next round, run by whoever picks it up, starts by reading it. It carries the
  context; this skill carries the design (Kaza, Meridian Display 2026-09-28).
- **Before the first commit on a WordPress site, check `.claude/` isn't served.** On
  WordPress on Pantheon the repo root *is* the docroot (`meridiandisplay.com/readme.html`
  returns 200), and these records list unpatched vulnerabilities and prices. Request
  a committed `.claude/` file's URL on test or live, next to the homepage returning 200;
  the file must not return 200. Dev is no proof: a locked dev answers 401 to everything
  (atr 2026-10-21). On Drupal only `web/` is served, so the repo root is safe.

Evidence, framing, design and components (§1–2, §7) all apply, as does the §8
integrity check. **Ignore §4's ten-section pitch structure**: this is a much
smaller genre.

**The layout:**

1. **Title block** — one band: the client logo on the left, and on the right
   three label-over-value columns split by hairline rules: *Project* (the
   domain), *Sheet* (`Maintenance`), *Round* (`2026.09`, mono). Nothing else.
   Settled on sisal (2026-09-23) after a six-cell grid read as a form. Issued
   duplicated Round, Prepared by is what the studio mark already says, and a
   standing "core support" cell said nothing that needed saying. On a phone
   the columns wrap under the logo and stay one row. Add an *Action required*
   column only when something is genuinely on the client and not already in
   motion (see the flag check below). When it applies, it goes in the header,
   not on page two. Call the platform "core", not "Drupal", throughout:
   *Core 10.6.15 → 10.6.17*, *Core 10 end of life*.
2. **Updated** — a version table of the ten or so components a non-developer
   recognises, each with a plain-language gloss (*Webform — contact and request
   forms*). One caption line absorbs the rest: *"plus 36 supporting libraries."*
   **Everything under a section heading steps in past the heading's words**:
   `--indent` is the heading icon's width plus its gap
   (`calc(var(--bm) + var(--bm-gap))`), and the section body sits at
   `calc(var(--indent) * 1.5)`, half an indent past the title, so it reads as
   belonging to it (cal 2026-10-19). su's and dmx's October records shipped flush with
   the title and Kaza caught both, so carry it on every doc. A sub-heading's text steps
   in another half indent. On a phone the body drops to 12px. The description line
   stays at `--indent`, level with the title. The table takes the indent on both sides, and its
   caption line rides with it. Everything else takes it on the left only. On a
   phone the table gives back its right side, or the component column wraps
   to six lines. One `section > :not(h2)` rule does it, so give component
   blocks `margin-block`, not `margin:0`, or they drop back out of the
   indent. Kaza's standard, sisal 2026-09-23. It replaced a narrower centred
   44rem column, which was too much margin and gave the table a treatment of
   its own. All three column heads share the small-caps label style. A `.num` rule
   applied to the `th` makes FROM/TO render as large mono with a stray arrow
   beside COMPONENT, so reset `thead th.num` and keep the arrow on the value
   cells only.
3. **Held** — only when something is. Every item gets its
   reason in the client's terms; without it, a short list of versions reads as
   the whole job. When nothing was held, cut the heading too. *"Nothing on the
   site was held back this round"* is a section answering a question nobody
   asked, and it was struck on ilc (2026-09-25).

   **Close every held item with an urgency line** (Kaza, Meridian Display
   2026-09-28): a tag (*Urgent* / *All good*) and one sentence on why. Grade it
   from a vulnerability database against the held version, not from memory
   (WPScan and Patchstack pages; the Wordfence JSON feed now needs a key), then
   against the site's exposure: if registration is closed and only admins have
   accounts, a flaw needing a login is out of reach, so only unauthenticated ones
   make an item urgent. A known exploitable flaw means update it, and when the
   update is walled, the Action names what unblocks it (the licence to buy). No
   known issue means *All good* (Kaza's change from *No rush*, kow
   2026-09-29), and saying so plainly is what keeps the client from
   treating every held item as an emergency. If an urgent item exists, it goes in
   the header's *Action required* cell, displacing a routine licence ask. Render it
   as a §7 **severity panel**, ending in an **Action** row with a checked link
   when the client has something to do.

   **A hold the client cannot perceive does not belong here.** Build tooling,
   composer plugins, anything whose entire existence is upstream of their site —
   cut it, however real the decision was. On wps *"three build tools … one
   carries a fault that breaks deployments"* was struck for exactly this: it
   describes our machinery, and the reader has no way to care. What survived
   each mapped to something on their site, and the section got sharper for it.
4. **Checked** — site-update's Phase 5 verification, in their vocabulary. *Careers
   listing and its job search filters*, not *`/careers` returned 200*.
4a. **POM+**: POM+ clients only (roster in
   [memory/pom/levels.md](../../memory/pom/levels.md)), placed before *Next*, with one
   heading per pass: *Access log*, *Error log*, *Performance*, *Bot protection*,
   *Search*, *Accessibility*. Each heading is a write-up in the client's terms: what
   the pass found and what we did in the round. **Keep it terse**: the problem in one
   plain sentence, then a short line that turns it to action (Kaza: *"HubSpot emails are
   bypassing cache, instead of respecting it. Lets fix it."*). Vary that line from heading
   to heading ("Let's change that.", "That's a quick fix."); the same phrase under every
   heading reads as a template (Kaza). Explanation belongs on the item in *Next*,
   not here. Work already done gets a clause, not a paragraph. The section ends in one centred **Fix**
   button that opens *Next*; a Fix per heading read as duplicates (Kaza). *Accessibility* says what was
   tested and what already works. The year plan isn't shown: it's ours, in the
   project's `.claude/memory/accessibility-plan.md`.
   **Every AshenRayne client gets this section too**, untiered and unnamed: a plain
   one-word heading (*Health* on dmx) and never the word POM. When nothing is quoted
   there is no *Next*, so a finding that needs action gets its own right-aligned Fix
   pointing at the item that acts on it, usually the Idea (dmx 2026.10).
5. **Next**: where the action is (Kaza, cal 2026-10-19). Work from the ordinary POM
   round comes first, Urgent first and then by importance. Then come the POM+ headings
   that have work, mirrored from *POM+* in the same order, each holding its own items
   (a `.next-group`). A group's items are indented under its heading by the same
   indent the sections use, and the groups sit well apart (cal: 43px, 25% up on the first
   draft) so each heading reads as its own block (Kaza). Findings live in POM+ and
   actions live in Next, so the two never repeat each other, and a pass with nothing to
   act on (a quiet bot month) gets no Next heading. Only when something is actually
   coming that the client needs to know about. A paragraph whose message is "nothing
   is required of you" is nothing, so cut it.
6. **Ideas** — improvements to the site, each one work we'd do. At
   least one comes from this round's search; see *One idea per round* below.
   Directly under the heading goes a small muted description line, so the
   client reads the section as a standing habit rather than a sales insert.
   Write it as an invitation to improve something for their visitors together:
   *"Let's help buyers find the right business faster."* Not a question, not a
   "How we…" fragment, and not "We can…", which reads as us selling rather than
   working with them (Kaza, cal 2026-10-19). Keep it to one short line.
6a. **Plan** — offer the next POM plan up, only when it is the right plan for
   this site, and never one that isn't approved yet. Never on an AshenRayne site: they
   have no plans. Which plan fits, and the rule
   behind offering it, are in [memory/pom/levels.md](../../memory/pom/levels.md).
   Name what the plan would do for *this* site, from what the round found: a
   commerce site's bot traffic, a listing site's search. When it doesn't fit, cut
   the section rather than offer it anyway.

   atr 2026.10 is the model Kaza confirmed (*"exactly what I want"*): one paragraph, opening
   on a real event from the site's own month (a bot crawling every wishlist link until we
   blocked it), then what the plan adds, then a close tying it to a finding in this record
   (*"Problems like this month's part-number search would turn up on their own"*). No
   price, no ask. Before drafting one, check the project's `.claude/memory/` for a hold
   on plan offers to that client.
7. **The studio mark**, centred at the very bottom. For August Ash that means the A
   shape alone, not the wordmark. See
   [doc-studio-mark](../../memory/preferences/doc-studio-mark.md). Once a
   round's template is built, this is the step that gets dropped.

Headings are one word, and a sticky section nav sits under the title block
(§7, *sticky section nav*). The panels, markers and flow strips named here are §7's
*Components*.

**Write it from the day the client reads it.** By then the round is deployed, so
everything the round did is past tense: *"Core 7.1.3 was a security release"*, not *is*;
*"the updates brought security fixes"*, not *carry*; a check that found nothing *showed*
nothing. Present tense stays for what is still true on their site (*"certificates download
as before"*) and for what is still open (Next, Held). Kaza caught *is* on atr 2026.10: *"to
imply it's been completed. When the client reads this, we'll have already pushed the
changes."*

The record ends where its content does: no closing stamp, no sign-off
paragraph. One short send-off line is allowed: centred, bold, a step below the
section headings, directly above the studio mark. It works when a Horizon has
opened the door (*"Now is the time to dream big."*, Meridian Display 2026-09-28). One
line, never a paragraph. The design and copy direction behind that, and behind the spacing,
width and heading scale, is §7's *A house style, still forming*. Read it before
drafting, since this record is where most of it was learned.

Pull the palette from the **theme's own variables file**, not the logo and not
memory, and inline the logo as an SVG with `fill="currentColor"` so the mark and
the document's brand colour cannot drift apart. On wps the theme's red was
`#e1251b` while `logo.svg` carried `#E02726` — near-identical, and visibly wrong
side by side.

### One idea per round

Every record carries one idea: a single change that would help the site do its
job better. That can mean smoother flow, content that's easier to find, or
clearer organisation, always measured against what *this* site is for, which is
different every time. An update keeps the site where it is. The idea is what
moves it forward, and it is the part a client reads as us paying attention.
Kaza's direction (ilc, 2026-09-25).

**Every idea is billable work, and it is written purely as a site improvement.**
Improving their site is the client's half; the work is ours. Aim at the first
and you get both, so the copy never needs our side of the ledger. Leave out
*"outside routine maintenance"*, *"additional work"* and anything else that
reads as the sale rather than the result. On ilc a traffic-and-caching log
review was first drafted as a separate *Recommended* section, pitched as extra
work. It belonged under Ideas, framed as *keep the site fast for real visitors*.

**When the finding is a gap in work already done, say so.** On dmx 2026.10 the
migration had already redirected the old site's links; the round's traffic scan
found the document downloads that slipped through. The draft pitched redirecting
them as though nothing had been done, which hid the work the client had paid for and
oversold the new ask. Kaza: *"this is us scanning the actual activity and finding
things missed, plugging holes."* Frame it that way: what's in place, what the real
traffic showed it missed, and closing the gap.

**The round finds one; the dev may add more.** The search below produces one
idea. When the dev brings another, such as a service they want to offer, it
goes under the same heading with the same three-paragraph shape, not a section
of its own.

**When the round turns up a rebuild, it gets a Horizon section.** One small idea
still leads, because it is billable now. When the evidence says the site needs more
than hours, pitch it under *Horizon* after the Ideas, as on su and Meridian Display.
Follow §2's *Show the complexity* rule: the full model goes in the
project's `.claude/memory/`, and the record gets a worked example of it.

**Start from what the site is for.** Before looking for problems, name the main
visitor and what they come to do. Read it off the site rather than the brief:
the main navigation, where the content volume sits, and what the forms collect.

```bash
ddev drush sql:query "SELECT type, COUNT(*) FROM node_field_data WHERE status=1 GROUP BY type"
```

On ilc, 765 resources and 162 products against 6 plain pages said *document
library for engineers and contractors*, not marketing site. That pointed the
search at how people find documents.

**Walk the main journeys and count.** For each of the two or three things a
visitor comes to do, do it yourself. Note how many steps it takes, how long the
list is, which filters it offers, and what comes back empty. The strongest
signal is **structure the site already has but doesn't use**: a field tagged on
every item that is never offered as a filter, a reference that could link two
pages and doesn't, a 185-row list with no paging. Ideas like that are cheap,
because the data exists, and easy to believe, because the gap is concrete.

**Read the code before calling something missing.** A listing's exposed filters
are in its view config, but a `form_alter` can hide one until something else is
set, and neither the config nor the default page will show you that. On ilc
the energy-code filter on typical drawings was pitched as missing, and only
turned up when the draft was checked: `ilc_filter` suppresses it until a
visitor chooses one category and presses Apply. The idea survived, reframed as
*surface the hidden filter and add the room one*, but the first draft told the
client something false about their own site.

```bash
grep -rn "<view_id>" web/modules/custom web/themes/custom   # alters and embeds
```

```bash
# every field a bundle carries, to set against what its listing exposes
ls config | grep "field.field.node.<bundle>."
grep -E "^\s+identifier:" config/views.view.<listing>.yml
```

**Test the obvious candidate before pitching it.** Commit history shows where
the pain has been, and an area tuned over and over is a lead, not a verdict. On
ilc, search had four rounds of commits behind it and looked like the obvious
idea. Twenty realistic queries (catalog numbers with and without hyphens,
product names, application terms) found it mostly working. The misses were
typos and ranking polish. The drawings page, which nobody had touched, was the
real gap. Probe with what a visitor would actually type, and read the view's
exposed-filter `identifier` before deciding a query returns nothing. ilc's is
`?s=`, and a probe against `search_api_fulltext` came back empty for everything.

**Pick one**, by four tests: it serves the site's main purpose, the client can
see it on their own site, it takes hours rather than a project, and it is built
from what they already have. One idea gets weighed. A list gets skimmed.

**Write it in three paragraphs**, under a title that names the outcome (*Find a
typical drawing by room and energy code*):

1. The problem in their terms, with a number and one concrete visitor:
   *"opens on all 185 drawings in one long table … An engineer after a Title 24
   classroom riser has to know that first step, then scan the list."*
2. The change, who it serves, and what makes it cheap.
3. The offer, in a paragraph of its own: *"We can add it for you in about two
   hours."* The estimate is the dev's call. Propose one and confirm it before it
   goes in, rather than printing a number you made up.

   Render the offer as a §7 **Work** marker: the price as hours @ rate = total (rate from memory/pricing/hourly-rate.json),
   nothing after it. Break the estimate down internally first, since that
   breakdown is what you confirm with the dev. When the idea is a stopgap ahead of
   a rebuild pitched under Horizon, say so in the idea and say that nothing built
   for it is thrown away (Kaza, Meridian Display 2026-09-28).

**Don't repeat last month's idea.** Read last round's record summary in
`.claude/memory/records/`, and the ideas log, before the search. Log each idea in the
project's `.claude/memory/ideas.md` with the round, the idea and what came of it,
and read that log before starting the next search. An idea the client declined
doesn't come back. One that went unanswered can be raised once more, if the
round finds nothing better.

**Always draft the idea; sending it is the dev's call.** This applies to every
genre, response documents included. The dev may cut the section from a given doc
for reasons that have nothing to do with its merit: the timing, the reader, or the
relationship. On metro's form-incident review, Kaza cut the Ideas section with
*"it was good, I'm just choosing not to follow-up with it this time"*. That was a
call about one doc. It doesn't retire the section, and it doesn't bank the idea
for later. Remove the section and its nav item, leave the idea out of the ideas
log, and draft one again in the next doc (metro, 2026-09-28).

### The support window — looked up, not recalled

The one claim in a maintenance record that is worth a client's attention is how
much runway the current major has, and it is exactly the claim most likely to be
written from memory and be wrong. On wps the draft said *"Drupal 10 is supported
into 2027, so there is room to plan"*; the schedule says **Drupal 10 reaches end
of life 9 December 2026**, and `10.6.x` is the final minor — about fifteen weeks
out, and the round had just taken core as far as Drupal 10 goes.

That single fact inverted the document. "Nothing needed from you" became a dated
upgrade window, and it belongs in the header cell rather than a closing
paragraph.

**Ask where the client already stands before flagging it again.** The next
month, wps's draft carried an *Action required: schedule Drupal 11* cell and
asked them to book an October window. The upgrade was already under way, so
the cell was cut and the copy turned into "in progress". A standing flag copied
forward from last month's record is the likeliest part of the draft to be out
of date, and the repo won't tell you. The dev will.

Check it every round, from the authority, at the moment you write it:

| Stack | Authority |
|---|---|
| Drupal | [drupal.org core release schedule](https://www.drupal.org/about/core/policies/core-release-cycles/schedule) |
| WordPress | [wordpress.org/about/roadmap](https://wordpress.org/about/roadmap/) — and the PHP version's own EOL, which bites first more often |

**On Pantheon, PHP's own end of life is not the site's exposure.** Pantheon backports
security fixes to PHP versions upstream has dropped and rolls them out across its
platform, so a site on 8.1 after 8.1's EOL is still patched. Don't write *"stopped getting
security fixes"* or *"each new flaw stays open"*: both are false there. The case for moving
up still stands, and it is a *Plan* item rather than *Urgent*: every fix now depends on the
host backporting it, which lands later than on a supported version and leaves the site
vulnerable for longer, and the newer version is supported upstream again (Kaza, atr
2026-10-21).

It also reframes the round's hold list: see site-update, *Reporting back*.

---

## 7. Design

Load the `frontend-design` skill first. Then:

**Write a complete HTML document.** `<!DOCTYPE html>`, `<html lang>`, and a `<head>`
carrying `<meta charset="utf-8">` and a viewport meta. Too obvious to state, and exactly
what gets skipped when the page is drafted with Artifact conventions in mind — there the
platform supplies the skeleton, here nothing does. A standalone file with no doctype
renders in **quirks mode**, where tables do not inherit `color`: every `td` falls back to
the `body` colour, so body cells go dark on a dark ground while `th` cells keep their
explicit colour and look fine. A missing charset separately makes the browser guess
windows-1252, turning every em dash into `â€"`. Both shipped once and cost three rounds of
"the labels aren't legible" while every contrast measurement came back correct — because
the CSS was never wrong.

**When a reviewer says something is unreadable twice, stop adjusting CSS and open the
file.** Measuring the styles you wrote only confirms what you intended. `getComputedStyle`
on the actual element tells you what the browser did, and walking the ancestor chain finds
where an inherited value gets dropped. That took about a minute after three rounds of
guessing.

**Self-contained or it isn't deliverable.** No external fonts, scripts, images or
CSS — it must open offline, on a locked-down laptop, from a zip. Verify:
`re.findall(r'(?:src|href)="(?!#)([^"]+)"', html)` returns empty.

**Sign it.** The studio mark goes centered at the very bottom, inlined. See
[doc-studio-mark](../../memory/preferences/doc-studio-mark.md) for which mark and where
the files live.

### A house style, still forming

This is a style Kaza and Claude are building together, each improving the
other's work, not a rulebook to comply with. Most of his notes say "better",
not "this value", and they land on drafts Claude shaped from its own instincts.
Claude's calls feed back the same way. On the wps record, several of Claude's
additions stuck without a note:

- repairing sentences left pointing at nothing after a cut
- spotting the stacked padding that made the first section break larger than
  the rest
- spanning the orphaned header cell rather than leaving a hole
- balancing the mark with a relationship instead of two numbers
- putting the checklist into columns once the page widened

The result is better than either would reach alone, so offer improvements
nobody asked for, and say briefly why each one helps. Below are the directions it has taken so far, with
the reasons. The numbers are where one document ended up: calibration, not
targets.

Bring your own judgement to every draft. Try things these notes don't cover,
and push back where one of them seems wrong for the document in front of you.
When you depart on purpose, say so in a line so it can be weighed together
rather than discovered. A correction is part of the process, not a failure.
Fold what it teaches back into this section.

**Design: let it breathe, and let structure show through space.**

- *Air over density.* A client doc is read at a desk, slowly, and cramped reads
  as hurried. When unsure, open it up. His first reaction to the wps record was
  "tight", and doubling the page padding, section gaps and row padding fixed it.
  The same instinct sets the width: a sheet squeezed into the middle of a
  desktop screen looks like a letter, not a document. He's settled around 1080px
  twice. Cap the *prose* for readability (~46em), and let tables, grids and
  callouts use the room. Something that leaves half the page empty, like a short
  checklist, can take columns.
- *Generosity has a ceiling.* The sign-off mark went from even-but-large to
  halved. Space is there to frame things, not to perform. Quiet elements (the
  mark, captions, labels) get enough room to be clearly separate and no more.
- *Size follows rank.* Whatever heads a section has to read above what sits in
  it. A tracked 11px uppercase label looks refined in isolation, and it failed
  here because the 15px bold item titles beneath it outranked it. Check the
  hierarchy by squinting at the whole page, not by judging one element.
- *Proximity carries structure.* Things belong to what they sit nearest. A
  heading with equal space above and below floats between two sections and
  blurs the boundary; it should hug its content, at roughly a third of the gap
  above it. Stacked paddings create false breaks the same way (an intro's bottom
  padding on top of a section's top padding), so look for places where two
  spacings add up.
- *A description line hugs its heading: about 4px, text to text* (su,
  2026-09-27, after "tighter" twice). Measure between the rendered text, using
  a `Range` on each text node, not between the element boxes. A description at
  1.6 line height carries about 5px of leading above its glyphs, so boxes 2px
  apart still read loose. Set the description's line height near 1.3, then tune
  the heading margin per heading level. A 26px flex `h2` and a 21px `h3` need
  different margins to land at the same 4px.
- *Balance is felt, then measured.* The mark had to look even top to bottom, and
  then it had to look even at every width. Solve that with a relationship
  (mirror the body padding) rather than two numbers that happen to match at one
  size.

- *Small marks echo the client's own shapes.* A template's heading bullet was
  shaped for the client it was drawn for, so re-derive it from the next
  client's logo instead of carrying it over. ILC's ring suited ILC. Atrix's logo
  is built from solid red dots, and Kaza swapped the ring for a solid dot
  because it "follows their logo better" (atr, 2026-09-25). He then took it
  further: the logo's dots step from dark to bright *across the cluster*, each
  dot one flat colour, so each section's dot takes the next step down the page,
  enlarged from 14px to 18px so the ramp reads. Sample the colours from the
  asset itself, since the eye misjudges a subtle ramp. Six dots across the
  logo's middle row gave `#a7161c`→`#e22437`, one per section. Check the bullet,
  the checkmark and the rule colour against the logo each time.
  The echo can stop at colour. Syracuse Utilities' logo is an orange disc with
  black stripes; the first draft striped the bullet to match, and Kaza chose a
  plain orange dot instead (su, 2026-09-27). Offer the literal echo, and expect
  the simpler one to win.

**Copy: a record, not a pitch, and every sentence new to the reader.**

- *Nothing the page already says.* He cut the date from a sentence that sat
  beside a box showing it, a *Held* item that only restated *Next*, and a
  paragraph that explained what the held items had already said. If the layout
  carries a fact, the prose doesn't repeat it. When a cut leaves a sentence
  pointing at nothing ("That is…", "described above"), fix the pointer in the
  same pass. He accepted those repairs without comment, which is the right
  outcome.
- *No ceremony.* No closing stamp, no sign-off paragraph, no "questions are
  welcome". The document ends when its content does, and the studio mark signs
  it.
- *Write from where the client actually is.* An "Action required" cell and a
  "book an October window" ask were both cut because the upgrade was already
  under way. Persuasion aimed at someone already in motion reads as not
  listening. The relationship's current state beats what the calendar implies,
  and only the dev knows it, so ask.
- *Their vocabulary, consistently.* On wps the platform is "core", not "Drupal",
  in every section. Small naming choices like that are his, and they apply to
  the whole document once stated.

**How he reviews, and how to meet it.** One note at a time, visual first, often
mid-edit. Apply the note, then look for the principle behind it and apply that
wherever else it holds (see §9, *Take the note, then generalise it*). Screenshot
the result at desktop and phone width before reporting, rather than reasoning
about it. When a correction teaches something new, add it here as a direction
with its reason, not as a value.

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

**Every doc gets a sticky section nav, and one-word section headings.** A reader who
can see what the document holds jumps to the part that interests them, and reads far
more of it (Kaza, Meridian Display 2026-09-28). Headings are one word where one will do
(*Updated, Held, Checked, Next, Ideas, Horizon*). The nav goes directly under the
title block and lists them:
- Mark the active section with `IntersectionObserver` and hide the nav in print.
- Use an opaque ground: a translucent bar shifts colour as it passes over
  differently-coloured sections.
- Give sections a *small* `scroll-margin-top` (about 8px). Their own top padding
  already clears the heading, and a large margin shows the tail of the previous
  section under the nav after a jump.
- Centre the items on desktop; left-align on a phone, where the list scrolls sideways
  and keeps the active item in view.
- No bottom border at rest. The hairline appears only once the nav is stuck, toggled
  by an `IntersectionObserver` on a 1px sentinel just above it. At rest the title
  block's rule already separates it.

**Every section collapses, and the nav opens what it jumps to** (Kaza, cal 2026-10-19).
The reader closes what they've read and keeps the page to what they're working through.
- The `h2` holds a `<button type="button" aria-expanded aria-controls>` wrapping the
  heading text and a chevron to its right. Down means open, rotated -90° means closed.
  The chevron sits **directly after the heading text** (a small gap, ~6px), not pushed to
  the far edge with `margin-left:auto` (Kaza, gif 2026-10-20): out at the edge it reads as
  detached from the heading it toggles.
  Everything after the heading sits in one `.sec-body` wrapper, which carries the
  heading indent in place of the per-child `section > :not(h2)` rule. A caption that
  set its own left indent then has to drop it, or it doubles.
- **One section open at a time, the first one on load** (Kaza, cal 2026-10-19).
  Opening a section, by its heading or the nav, closes whichever was open, and clicking
  an open heading closes it. A `#hash` on load opens that section instead of the first.
  The markup ships open and the script sets the state on load, so
  the doc still reads in full without JavaScript, and it prints in full
  (`.sec-body[hidden]{display:block!important}` in the print sheet, chevrons hidden).
  The nav highlights only an open section.
- **A finding that needs action links to the item that acts on it.** When a section
  says something needs doing (POM+ → Search) and another section holds the fix (its
  Next item), link the first to the second. Otherwise the doc says something needs
  doing without establishing the next step (Kaza, cal 2026-10-19). It's a **Fix** button,
  right-aligned on its own line under the finding, never inside a sentence: an `<a>`
  styled as a pill button (it navigates, so it stays a link), with an `aria-label` that
  names the target (`Fix: Tell search engines and AI who Calhoun is`), since "Fix" alone
  says nothing to a screen reader. **Every follow-up link in a doc works this way**, wherever it points
  (Kaza): the same button, the same open-scroll-flash. Give the target an `id`, and
  `scroll-margin-top` to clear the sticky nav. Clicking it opens the target's section
  through the same handler the nav uses: one document-level click listener on
  `a[href^="#"]` that opens whichever section holds the target.
  Then the target flashes once, a brand-accent ring fading out over about a second and a
  half, so the eye lands on it (Kaza). Start the flash on `scrollend`, with a short fallback
  timer for when the target is already in view and nothing scrolls, and clear the class
  on `animationend`. Under reduced motion it shows the ring without the fade.
- **A section's description line stays with its heading.** It sits between the `h2` and
  the collapsing body, not inside it, so a closed section still says what it's for
  (Kaza, cal 2026-10-19). Only where a section already has one: don't write a
  description for every section just so each heading has a line under it.
- **Toggling must not move the heading** (Kaza: "the header lowers, then moves back up").
  Keep the space *above* every heading constant and give an open section its extra room
  *below* (`section:has(> h2 [aria-expanded="true"]){padding-bottom}`); padding that
  changes above the heading shifts it on every click. When opening one section closes
  another above it, hold the clicked heading still: measure its top before, then
  `scrollBy` the difference after. Near the top of the page there isn't enough page to
  hold it, and it settles at its natural spot, still in view.
- A nav click opens its section in the click handler, before the browser's own jump,
  so the anchor lands on content rather than a closed heading. Do the same for a
  `#hash` on load.
- Cal's October 2026 record is the reference implementation.

### Components

The standing parts our docs are built from. Each one was settled through review, so
reach for these before inventing a new device, and extend this list when a new one
earns its place.

**Markers: a tag and hanging copy.** A row with a small solid pill tag (*Action*,
*Work*, *Urgent*, *All good*) followed by the copy, laid out as a grid:
- The tag sits in a fixed-width column (about 84px), so every row's copy and link
  start at the same x down the whole panel. Wrapped text hangs under the copy, not
  under the tag.
- The tag takes the colour of the panel it sits in, so the same markup reads red in
  an urgent panel and blue in an idea.
- A link goes on its own line under the copy, bold, underlined, with a trailing
  "→".
- **An Action row ends any note that asks something of the client's site.** Once they
  are alarmed, the next thing they read is what to do, with a link to do it (a
  licence, a renewal). Don't end on a stopgap sentence instead. An Action is never
  "contact us".
- **An Action row says what the client does, and nothing about cost.** "No cost from
  us" on a task of theirs reads as a favour being counted (Kaza, cal 2026-10-19).
- **No action, no Action row.** When the hold is ours to resolve (waiting on an
  upstream release, a test we'll schedule), leave the row out rather than writing
  "None needed". A row that says nothing is required is filler, and it dilutes the
  panels where something is (Kaza, kow 2026-09-29).
- **A Work row carries an offer**: the price as math and nothing else,
  *Approximately 2 hrs @ $200 = $400*. The idea above it already says what the
  work buys, so a trailing description only repeats it. Showing the hours and the rate lets the
  client check the total, which is worth more than a bare number. **Take the rate
  from [memory/pricing/hourly-rate.json](../../memory/pricing/hourly-rate.json)**, never
  from memory or an old doc: it will change, and that file is the one place it changes.
  Record the rate a round quoted at in the project's round record, since a later rate
  rise mustn't rewrite what a client was offered. The tag reads *Work*, not *Quote*
  (Kaza, cal 2026-10-19).
  **AshenRayne clients get the price alone** (*$600*): Kaza doesn't bill them by the
  hour, he states what he's billing (dmx 2026-10-19). No hours, no rate, no
  *Approximately*. The same goes for billed work and anything else priced in the doc.
- **A Limit row names what holds the site back**, stated as the case: what it could
  be, and what stands in the way. Meridian's order-process panel ends on one: *"far
  more potential than it can reach today, and getting there takes a rebuild."* It's a
  statement, not an ask.
- **Billed work gets a Work row too**, in the same math and nothing else
  (*2 hrs @ $150 = $300*). It is always green, whatever panel it sits in, so paid work
  reads as a win: a green tag on a green-tinted row (about 12%; lighter vanishes on a
  coloured panel), no border and no top rule. An outline was tried and cut (Kaza, su
  2026-10-19). Every amount in a doc takes this `x hrs @ $rate = $total` form,
  except on AshenRayne docs, which state the price alone.

**Approving work: the client picks what we do and sends the doc back** (Kaza, cal
2026-10-19). The colours below are cal's; carry the concept, not the hexes. Approved
takes the client's strongest affirming colour, Save uses their own attention colour and
their confirm colour, and the to-do toggles use a clear stop and go pair drawn from the
palette wherever it allows. Every item carrying a Work row is approvable; anything without one (a task
for the client's own team) is not.
- **Approved, the whole item turns one affirming brand colour** (cal: its deep green),
  whatever severity it started as (Kaza): outline, heading, tags, the price, and the divider lines. Set the dividers
  to that colour at full strength, because a 1px line in a tint of it reads as grey.
  An Urgent red item that stayed red once approved looked unapproved.
- A large plain **?** in the item's top-right corner, grey, with no circle or border
  behind it (Kaza), `title` "Approve this work". The approved checkmark matches it:
  plain, same size, in the brand green. Keep a ~40px click area around the glyph. Clicking it
  marks the whole item approved (brand-green outline and tint) and swaps the ? for a
  checkmark; clicking again undoes it. It's a `<button aria-pressed>` whose
  `aria-label` names the item.
- The first approval opens a short note (a `<dialog>`, never `alert()`): they're
  approving work, and once they've chosen, they press Save and email the doc back.
  Don't name us in it: who it goes back to is implied (Kaza).
- **They have to save**, because a browser can't write back to the file it opened. Save
  sits at the right edge of the nav bar, aligned with the content while the section links
  stay centred (Kaza), and falls back to the end of the scrolling row on a phone. It is gold (the client's own yellow where they have one)
  while there are unsaved choices, green once saved. **It is always visible on a doc that holds
  something to answer** (Kaza, gif 2026-10-20): green *Saved* when nothing has changed, gold
  *Save* once something has. A doc with nothing to approve, decide or tick has no Save at all;
  the script hides it when no `.decision`, `.approve` or `[data-done]` is on the page.
  Hiding it until the first choice, as cal's record did, left the reviewer asking where
  saving was. The snapshot writes it back as green *Saved*, not hidden. It uses `showSaveFilePicker`
  where the browser has it (Chrome, Edge) and downloads a copy everywhere else, and a
  `beforeunload` prompt guards unsaved choices.
- State lives in the markup as `data-approved="true"`, and the saved file is a snapshot
  reset to how the page ships (sections open, script-added controls stripped), so the
  returned copy opens with their choices marked and still reads in full without script.
- **The client's own tasks get a done toggle instead** (Kaza, cal 2026-10-19). A list
  they work through themselves, like cal's 37 listings to check, isn't approvable work,
  but they should be able to tick it off. Each entry is a small card with a red **×**
  in its corner on a red tint; clicking marks it done, turning the × into a check and
  the tint to green, and clicking again reverts it. It's stored as `data-done`, counts
  toward Save's unsaved state, and doesn't trigger the approval note.
- Print shows only the approved checks.
- Cal's October 2026 record is the reference implementation, tested through a full
  save-and-reopen round trip.

**Decisions: a question the client answers in the doc** (Kaza, gif 2026-10-20). When we
need a call from them, ask it where the topic lives, not only in a closing question list,
and let them answer on the page.
- The panel: the question as its heading and one line of context. Then a *Recommended*
  marker with our answer and a **Choose** button, a centred **or** between rules, and
  a labelled textarea for their own answer.
- Picking one hides the other: choosing the recommendation hides the textarea and the
  *or*, and typing in the textarea hides the recommendation and the *or*. Clicking
  *Chosen* again, or clearing the text, brings both back. Answered, the panel turns
  green. Keep `[hidden]` winning over the panel's own `display` rules
  (`.decision [hidden]{display:none!important}`), or the toggle silently does nothing.
- It saves through the same Save button and snapshot as approvals. The choice is stored
  as `data-choice="recommended"`, and the typed answer is written into the textarea's
  text in the snapshot, since `.value` never reaches the markup. On load the script reads
  both back, and Save starts as *Saved*. The first answer opens the same short note.
- Once a decision covers a question, take it out of the Questions list. Asking twice
  invites two different answers.
- Print shows only the answer given: an unpressed *Choose* is hidden.
- **A yes/no that gates content** (gif's *"Are we moving the store off Klaviyo?"*): Yes
  and No buttons, and everything that only matters on a yes carries
  `data-gate="<panel id>"` and stays hidden until Yes, including a follow-up item in
  Questions. No keeps it hidden and shows our one-line answer in the panel. Clicking the
  pressed button clears it. The intro that frames the question stays visible above it,
  worded conditionally (*"if the store moves…"*). Saved as `data-answer`. The snapshot
  strips `hidden` from gated content, so the file still reads in full without script.
- **A plain yes/no question gets a check and an X after the sentence** (Kaza, gif
  2026-10-20). No panel and no buttons labelled Yes/No: two round icon buttons, green when
  the check is pressed, red when the X is. Each carries an `aria-label` that says what the
  answer means (*"Yes, remove it"*). Same `data-answer` state and Save as the panel version.
  Keep a Questions list to what the client must answer. Questions we can settle with them
  directly, or that only matter to our build, stay out of the doc.

**Severity panels.** A note that grades something (urgency, risk, status) becomes a
tinted panel of its own, coloured by severity: red for urgent, amber for plan-for-it,
green for no rush.
- One `--u` custom property per severity drives three things: the fill (the hue at
  about 9%, via `color-mix`), the text (a dark shade of the same hue) and the solid
  tag. Retuning a level is then one line.
- A panel ends with an Action row only when the client has something to do. Plain
  green *All good* panels matter as much as the red one: they stop the client treating
  everything held as an emergency.

**Flow strips.** A process becomes numbered cards in a grid: mono `01`–`08`, an
optional actor label (*Buyer*, *Meridian*), a bold step name and at most one line of
detail.
- Colour the card's top edge by actor, using the client's primary and secondary brand
  colours, so hand-offs show at a glance.
- Actor colours have to differ in lightness, not just hue. A 4px edge in navy and one in
  dark blue read as the same actor (Kaza, gif 2026-10-20: `#1f293b` beside `#004a7d`). When
  the palette has two dark tones, take the brighter sibling for one of them (gif's
  `#36aece`), and carry that actor's colour into any other diagram in the doc.
- Eight steps sit as 4 × 2, and two columns on a phone.
- When two flows exist (the shared process and the customer's own side), give each
  its own strip, not one long one.

**Mock UI, mid-task.** When the pitch is an interaction (drag into boxes, split a
cart), draw a static mock of it caught halfway: some state filled in, one element
mid-drag, a count of what's left.
- It uses the worked example's own numbers, so it reconciles with the tables after it.
- Label it illustrative in an `aria-label` or caption.
- The picture sells an interaction better than any sentence about it.

**Evidence strip.** Two or three measured figures in large mono, each with a short
line of what it counts, on a left rule in the brand's secondary colour. Only numbers
that survived §1's checks go here.

**A logo drawn for a dark ground sits on a plate of its own header colour.** Meridian's
yellow-and-white mark vanished on white, so the title block puts it on a rounded plate
of the site's header blue. Say so when you do it; it's a departure from the plain
logo-left title.

**No closing ask to an existing client.** They know how to reach us and who to talk
to. The whole document is the push, and if it doesn't land, one line won't either. A
"let's talk" or a contact link at the end reads as needing the work, which undoes
the confidence the rest of the document built (Kaza, Meridian Display 2026-09-28).
End the pitch on the case itself, as a statement. Action rows are for things the
client has to *do* about their site (renew a licence), never for contacting us. A
cold pitch to a prospect is the only place a contact line belongs. The same goes for a
scoping question to close a record's Horizon (*"What does your team work from
today?"*): it's an ask in disguise, and it was cut. Scoping starts when they reach
out.

**Verify every link before it goes in.** Fetch it and read the page title. When
Cloudflare answers a script with 403, as augustash.com does, load it in the headless
browser. A pricing or renewal link that 404s in a client's hands undoes the note it
sits in.

**Quality floor, unannounced:** responsive, keyboard focus visible, reduced motion
respected, and a print stylesheet that flips dark bands to white.

---

## 8. Delivery

- **Reload the tab the reviewer already has; never `open` again.** `open` makes a new
  tab on every call, and after a dozen notes the reviewer is hunting through duplicates
  (Kaza, su 2026-09-27). `open` once for the first look. After that, reload that same tab
  through the [firefox-devtools](../firefox-devtools/SKILL.md) server: `list_pages`
  once, keep the doc tab's `pageId`, then `navigate_page { pageId, url }` after each
  edit. Bump a query string each time (`?v=3`): a navigation that changes only the
  `#anchor`, or repeats the same URL, scrolls without reloading, and you end up
  reviewing the old version. If Firefox wasn't started through `firefox-claude`, ask the reviewer to relaunch
  it rather than falling back to `open`. Take your own screenshots on the headless
  `firefox-solo` server, not in their browser. If it won't start, headless Chrome
  (`--headless=new --screenshot`) works. It won't render narrower than about 500px,
  though, so a `--window-size=390,…` shot shows content cut off on the right that
  isn't really there. To see a true phone width, load the doc in a
  `<iframe style="width:375px">` inside a wrapper page, and pass
  `--allow-file-access-from-files` (metro, 2026-09-28).
- **Verify the HTML after every structural edit** — print the result, don't assume.
  Renumbering, remapping and reordering have all failed silently. (This rule used to
  be about keeping a markdown twin in sync; the twin is gone, the verification isn't.)
- Split depth into `technical-appendix.md` rather than cutting it — the presenting
  dev needs it even though the client shouldn't see it.
- **Ship a folder only when there is something to keep together.** If the HTML is
  genuinely self-contained and travels alone — no appendix going with it, no images,
  fonts or data files — send the loose `.html`. It opens by double-click and needs no
  unpacking. Wrapping one file in a zip is packaging overhead the recipient has to
  undo for nothing.
  When there *are* companions — the `technical-appendix.md`, screenshots, an evidence
  export — zip a directory containing them, named readably (spaces are fine), plus a
  short `README.txt` saying what each file is, what the evidence base was, and which
  file to open. That survives being forwarded to someone who wasn't in the
  conversation; a bare pile of attachments does not.

**Run an integrity check before packaging.** Cheap, and it has caught real breakage:
starts with `<!DOCTYPE html>` and declares `<meta charset="utf-8">`, no external
`src`/`href`, balanced CSS braces, balanced `<div>`/`<section>` counts, no rules with a
missing selector, every nav anchor resolving to an existing id. If you can open it in a
browser, `document.compatMode` must be `CSS1Compat` and `document.characterSet` `UTF-8` —
anything else means the head is wrong.

## 9. Working with the reviewer

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

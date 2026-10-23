---
name: pom-plus
description: The extra work a POM+ client gets on top of the routine update round — every round a log, performance, bot-protection and search (SEO and AI findability) pass; every quarter an accessibility scan, with the first year opening on a full audit and a year plan. Use during a site-update round for a client listed as POM+ in memory/pom/levels.md, after the update is verified and before the client record is written. NOT for POM clients (the update round is the whole job), and not for a one-off audit nobody scheduled — load accessibility-audit or log-audit directly for those.
---

# POM+ round

A POM+ round is a [site-update](../site-update/SKILL.md) round plus the passes below. Which
clients are on it, and what each plan includes, lives in
[memory/pom/levels.md](../../memory/pom/levels.md). Check it at the start of every round;
plans change, and this skill doesn't carry the roster.

**What the passes are for.** First, to make the client's site better, most important items
first. Second, every finding is a chance for work we'd do for them, quoted with a Work row
in the record. The first aim decides the order, never the second: the
[client-report](../client-report/SKILL.md) goal statement is the rule here too.

Run the passes after site-update's Phase 5, on the freshly updated site. Each one ends in
findings, sorted three ways:

- **Fixed in the round.** Small, safe and clearly ours: a missing redirect, a stray
  `noindex`. Commit it on its own, per site-update Phase 6.
- **Quoted.** Worth doing and bigger than the round. It goes in the record's *Next*, under
  that pass's heading, with a Work row.
- **Watched.** Not worth acting on yet. One line in the round record
  (`.claude/memory/records/<round>.md`), so next round can tell a trend from a blip.

Which way a finding goes depends on the pass. These are defaults, not rules (Kaza,
2026-10-19):

- **Error logs: mostly fixed in the round.** Most fatals and warnings are
  straightforward. Quote only the exception that is real work.
- **A finding that can hold up traffic is Urgent.** Even when the fix is small, it's
  work on the client's site, so it goes in *Next* under its pass as an Urgent item with
  a Work row rather than being fixed quietly. Tell the client it needs fixing and bill it. Cal's
  Campaign Monitor timeout (one hour) was the first (Kaza, 2026-10-19).
- **Access logs, and the bot protection built on them: quoted.** Doing these properly
  usually means installing a module and tuning it, which is additional hours on a Work
  row. Expect the work to be front-loaded, then become monitoring and tweaking in later
  rounds.
- **Performance: quoted.** Cache tuning across the host, site and CDN layers is
  usually additional hours, so it goes in as a recommendation with a Work row.
- **Search: quoted.** Sweeping scans, deploy hooks written for live, and broad
  adjustments are project-sized. The same shape applies: front-loaded, then monitor and
  adjust.
- **Accessibility: quoted.** The quarterly scan comes with the plan; the fixes it
  finds are additional hours, quoted per quarter from the year plan.

Access logs, performance, search and accessibility share a shape: the work is front-loaded.
The first assessment and what it turns up are the quoted hours. After that the pass
settles into adjusting and fine refinement, and small adjustments can land in the round
without a Work row. Exceptions come later, once that first assessment is done.

**When agents run the passes, verify every finding before it reaches the developer.**
Splitting the passes across agents is quick, but they are often wrong with confidence.
On cal (2026-10-19) one read Pantheon's edge as the client's Cloudflare and proposed a
purge fix for staleness that didn't exist; a dev test disproved it in a minute. The
accessibility agent caught two of its own false findings. Re-check the evidence behind
each claim, and test anything that would become a Work row, before presenting it.

**The developer reviews the passes in the record itself.** Write the verified findings
into the doc and hand it over; no separate walkthrough first. That is client-report's
review rule.

**A finding two passes touch goes to the pass that matches its nature.** Headings are
the usual case: heading structure, ARIA and roles are accessibility, while titles,
summaries and what a page says about itself are search (Kaza, cal 2026-10-19). Quote it
once, in that pass, so the client isn't billed twice for one fix.

Work rows price at the rate in
[memory/pricing/hourly-rate.json](../../memory/pricing/hourly-rate.json).

Read last round's record before starting each pass. A number means little alone and a lot
next to last month's.

---

## Every round

### Logs: access and error

Load [log-audit](../log-audit/SKILL.md) and take its recurring entry point: scanners, abusive
clients, 502/504s, fatals, slow requests. Add the site's own error log,
`ddev drush ws --severity=Error` locally and the same through terminus against live
(read-only). Report what is new since last round, not the standing background.

### Performance: the cache layers

Three layers, checked on the pages that matter (home, the main listing or catalog, the top
landing pages):

- **CDN.** First work out *whose* edge it is, from the DNS answer, not the headers:
  Pantheon's own edge sends Cloudflare headers too, and most client zones don't cache HTML
  ([proxying-pantheon-ssl-mode](../../memory/cloudflare/proxying-pantheon-ssl-mode.md)).
  Before calling a page stale, test it: re-save a node on dev and watch the next request.
- **Host.** Pantheon's edge: `age`, `x-served-by`, and whether `cache-control` allows it to
  cache at all.
- **Site.** `x-drupal-cache` and `x-drupal-dynamic-cache`; a page that is `UNCACHEABLE` or
  sets a session cookie for anonymous visitors defeats both layers above it.

Diagnosis lives in [caching](../../memory/drupal/caching.md),
[bigpipe-pantheon](../../memory/drupal/bigpipe-pantheon.md) and
[edge-ttl-vs-tag-purge](../../memory/drupal/edge-ttl-vs-tag-purge.md). For worker saturation,
use the [New Relic audit tool](../../memory/augustash/newrelic-audit-tool.md).

### Bot protection

Is the protection in place and still doing its job? Check the Cloudflare rules and their
recent events ([waf-rule-tool](../../memory/cloudflare/waf-rule-tool.md)), and set them
against what the access log showed. Check
[waf-blocks-acme-renewal](../../memory/cloudflare/waf-blocks-acme-renewal.md) on every rule
change, because that failure surfaces two months later. On a Drupal site with facets or
search, [drupal_cache_protection](../../memory/augustash/drupal_cache_protection.md) is the
site-side half.

### Search: being found, by search engines and AI

The goal is that the site presents itself correctly in its space, so the people looking
for this client find them. Most of them no longer scroll organic listings: they ask an AI,
or read Google's AI answer above a page of sponsored results, and almost nobody reaches
page two. So the pass asks whether search engines *and* answer engines can read the site,
and whether what they read says plainly who the client is, what they do, for whom and
where (Kaza, 2026-10-19).

- **Can it be read?** robots.txt and the CDN's bot settings must not shut out the AI
  crawlers (GPTBot, ClaudeBot, PerplexityBot, Google-Extended) by accident. Cloudflare's
  AI-crawler blocking is a one-click default that does exactly this. Key content has to be
  in the server HTML, not rendered by script alone. Note whether there's an `llms.txt`.
- **Does it say who they are?** Organization or LocalBusiness structured data, and one
  consistent name, address, phone number, service area and office list across the site.
  The things a client sells or lists (products, listings, services) should be described as
  what they are.
- **Does it answer what people ask?** The main pages should state the offer the way
  someone asking an AI would need to read it ("how do I sell my business in Minnesota").
  Plain answers and FAQ-shaped content get quoted, and marketing copy doesn't.
- **The technical basics still count:** unique titles and meta descriptions, canonicals,
  the sitemap ([pantheon-robots-txt](../../memory/drupal/pantheon-robots-txt.md)), share
  cards ([neo-metatag-description-slogan](../../memory/augustash/neo-metatag-description-slogan.md)),
  stray `noindex`, and 404s that carry traffic
  ([redirect-shadowed-by-alias](../../memory/drupal/redirect-shadowed-by-alias.md)).

This pass is the newest. Sharpen it as rounds run, and keep it pointed at how people
actually look for businesses now, not at how they did.

---

## Every quarter: accessibility

**The windows are fixed, and every POM+ client runs in the same one.** Calendar quarters;
the scan runs in the first update round of January, April, July and October. A client
missed in that round runs in its next round inside the same quarter. One shared window,
rather than a date per client, keeps the schedule in one head.

**Is it due?** The tracker, [memory/pom/accessibility.json](../../memory/pom/accessibility.json),
lists the quarters done per client (`"CAL": ["2026-Q4"]`). If the current quarter isn't in
the client's list, it is due.

```bash
python3 -c "import json,datetime as d;t=d.date.today();q=f'{t.year}-Q{(t.month-1)//3+1}';j=json.load(open('vendor/augustash/claude-config/memory/pom/accessibility.json'));print(q,{k:q in v for k,v in j.items()})"
```

### The first quarter of a POM+ year: audit and plan

When the client's list is empty, or four quarters have passed since their last audit, the
quarter opens a year:

1. **Audit.** Run [accessibility-audit](../accessibility-audit/SKILL.md) in full. We use our
   own method, not a module or an overlay; it worked well on md.
2. **Plan the year.** Split the findings across four quarters, most important first. The
   split doesn't need to be precise, and front-loading is expected and fine. Keep the plan in
   the project's `.claude/memory/accessibility-plan.md` so next quarter starts from it.
   **The plan is ours.** The client never sees it, only each quarter's first pass (Kaza,
   cal 2026-10-19).
3. **Recommend the first quarter.** Each fix is its own Work item under *Next →
   Accessibility*, ordered by importance, so the client can
   approve them one at a time.
   Expect the dev to cut the hours. The audit agent priced cal's first quarter at 16 h, and
   Kaza quoted 4.

### The client's requirements govern the plan

Work out what the law asks of *this* client before ranking anything (Kaza, metro 2026-10-23).
The rule decides the scope and the order; a vendor score (Siteimprove and the like) is at most
a second line. Built first on metro; the record there is the reference.

1. **Which rule set.** A state or local government body is the ADA Title II rule:
   [ada-title-ii-web-rule](../../memory/accessibility/ada-title-ii-web-rule.md), a living
   memory with a review cycle. Other kinds of client (a private business, a federal
   contractor) need their own set; write it the same way before using it.
2. **Establish, never guess.** Every statement traces to the regulation, WCAG or the DOJ's
   published explanation. When the text doesn't settle a question, find the definition (the
   memory says where) and record it there before it reaches a client.
3. **Gather the site's facts.** The vendor tools it carries under contract, named. Its
   documents: how many, and which are still used to apply for or take part in something
   (search titles for application, form, permit, request). Old material that a marked archive
   would take out of scope. What sits behind a sign-in.
4. **Mark all 50 criteria** Supports / Partially / Does not / N/A / Not yet tested from the
   verified findings. Never mark one met without testing it.
5. **Rank by the rules.** Exempt content drops out; what stops someone finishing a task
   (§ 35.205's minimal-impact test) comes first; then reach; the deadline sets the pace.
   On metro this put the permit-form PDFs ahead of every page fix.
6. **Write the "Your requirements" page** from the block library in
   `templates/client-report/accessibility-rules.html`: only the blocks that apply, filled with
   the site's facts, ending with how the rules order the plan. It opens full screen from the
   Accessibility section's upper right. Two sites of one client can have different pages.

### Later quarters

Rescan to catch regressions and new content. Report progress against the plan, adjust the
plan where the site has changed, and put the coming quarter's items under *Next →
Accessibility* with Work rows.

### Marking it done

The quarter is done when the scan has run and the record is drafted. Add the quarter to the
client's list in the tracker, then commit and push claude-config like any memory write
([memory-management](../memory-management/SKILL.md) §6). The tracker is a memory file, not a
skill, so the project's lock doesn't need to move for it.

---

## The record

[client-report](../client-report/SKILL.md) §6 owns the layout. *POM+* has one heading per
pass (*Access log*, *Error log*, *Performance*, *Bot protection*, *Search*,
*Accessibility*) carrying the findings; *Next* mirrors the headings that have work and
carries the items; one Fix button at the foot of POM+ opens Next. Write each finding in the
client's terms, the same as *Checked*.

---
name: site-chat
description: Building or extending an AI chat on a client site that answers from the site's own pages and data and brings qualified readers to a person (live, or as a lead). Covers discovery, data the AI can trust, the answer pipeline, live hand-off, the team's audit and coaching, nightly learning held to a test set, and deploy. NOT for dropping in a vendor's chat widget unchanged (see the livechat memories), and not for a generic AI feature with no reader-facing chat.
---

# Site chat

A chat on a client's site that answers readers from **their** material, and gets the
ones with a real need to an advisor. Built first for Enterprise Minnesota
(enterpriseminnesota.org, 2026-11); the reference implementation is that repo's
`wp-content/plugins/aai-chat/` and its notes in `.claude/docs/chatbot/`. Copy and adapt
it rather than starting over.

**The goal, stated to the AI in its own guidance file:** help readers generously, and
bring the most qualified ones to a person. A chat that only answers is a FAQ; one that
only collects leads is a form.

## 1. Discovery: what readers actually ask

Measure before scoping. The site already says what readers want:

- **The site's search log** (SearchWP `wp_searchwp_log`, Drupal search logs). Filter bots
  first, since probe strings dominate raw logs. People type keywords, not questions.
- **Form inquiries** over a year or two, keyword-grouped by topic. On EM, 2 of 379
  inquiries mentioned the survey everyone assumed was the point; the rest wanted help
  with their business. That reshaped the whole design toward advisors.
- **Share of inquiries outside office hours** (EM: 42%). That's the case for leads.

## 2. Data the AI can trust

**Never let the AI retype figures.** A wrong number under the client's name is the
failure that matters. For structured documents (survey crosstabs, price lists,
specs), **code reads the numbers; the AI only labels.**

- `pdftotext -layout`, then parse by column position. EM's crosstabs: 375 tables,
  76,751 figures, 5 distinct column layouts ("banners").
- **When a row's value count equals the column count, take values in order.** Position
  matching drifts a character or two between pages and silently credits a figure to
  the neighboring column. Report every row that fell back to position.
- **Column labels are a per-year map written by a person** (or AI-proposed, then
  checked), keyed by banner and column index. Headers change year to year: EM's
  2026 reordered three banners. Reusing last year's map would have mislabeled them.
- **Output a JSON file per year as the checked copy**, then import it into a table.
  Extraction runs where the PDF tools are (ddev); Pantheon only imports the JSON.
- **Cross-check against a separate document** (EM: crosstab totals vs the topline PDF).
  A clean parse only proves the parser agrees with itself.
- A `-` in a percent row beside a nonzero count means under 0.5%, not zero.

**Unreleased data is gated in SQL**, not by remembering not to send it: a hidden year's
rows are never selected, so no prompt can contain them. Release is a per-year time
checked on every request (not WP-Cron), plus a manual override for us. The first
request after the time runs the same finish as a manual release (cache purge).

## 3. The answer pipeline

1. **Free checks first:** junk regex built from the search log (match exploit
   syntax like `\think\app`, never bare words: "think" blocked "I'm thinking of
   selling"), length, per-IP rate limits, a monthly cap. Bots never reach a model.
2. **A cheap screen (Haiku):** scope (question / wants a person / off-topic / junk),
   **picks the data to use from a catalog** (one line per survey question, numbered),
   and names the breakdowns implied. Keyword search alone failed: every question had a
   "Very confident" column, so "confident" matched everything. The catalog lets the
   screen map "worries" to "how concerned". Tell it to select breakdowns whenever the
   reader names a kind of company.
3. **The answer (Opus, low effort):** only from numbered sources (`S1`, `P1`), returned
   as JSON with `source_ids`. **Code renders the citations**, so none can be invented,
   and **rejects any figure with no source**.
4. **Business questions get a real answer first, then the advisor offer.** "A brief
   pointer and an advisor" produced link lists; readers who get substance take the
   next step.
5. **Cache first answers on what the screen picked**, not the wording (rewordings hit,
   Opus skipped, ~1.3s vs 4.5s). Its search terms drift run to run, so leave them out
   of the key. Key in a knowledge version (guidance + learned notes + released years)
   so learning or a release retires entries; expire on disuse, never on age.

Cost at EM's volume: about 1.5¢ per answered question.

## 4. A person: live or a lead

- **In hours AND someone accepting chats → live; otherwise a lead.** The site decides
  hours, so the vendor's cheaper plan without working hours does.
- **Live chat in your own window via the vendor's customer API**, not their widget:
  the browser holds the customer WebSocket, so the host carries no long connections.
  Text/LiveChat specifics: [text-customer-chat-api](../../memory/chat/text-customer-chat-api.md).
  Send the bot conversation as the chat's opening message (agents-only), and report
  live-started and first-reply events back for the audit.
- **Leads as the CMS's own form entries** (Gravity Forms), copying the contact form's
  recipients **and its delivery service (SendGrid) only on Pantheon**. Locally it would
  email the client's real inboxes. Testing a lead on a multidev does too.
- If the client only wants their vendor widget behind a menu item, that's the
  [livechat-custom-launcher](../../memory/drupal/livechat-custom-launcher.md) route.

## 5. The team's screens

- **Audit (landing):** every question, accordion rows, a status tag per row, a key above
  (statuses and actions in **separate panels**). Statuses: Answered, Advisor offered,
  Advisor responded, Left details, Missed, Couldn't answer, Off-topic, AI unavailable.
  Actions: **Coach** (how we'd have handled it), Save (empty = exactly right), Clear,
  Spam (also on closed rows). Rows stay in place colored after acting.
- **Coach, don't edit.** Kaza rejected editable answers: they become memorized one-offs.
  Coaching generalizes.
- **Report:** volume, answered share, real cost from token usage, an **Advisors** row
  (requested / offered / contacted / missed; missed is the one to watch), a per-day
  timeline with zero days drawn, what it couldn't answer, common questions with their
  rewordings.
- **Settings:** hours per day (holidays = close the day that week), a reach-out promise,
  survey years (upload to private storage, release time). Early release is limited to
  augustash.com accounts.

## 6. Learning, without letting readers steer it

The team's actions are the trusted signal; readers' words are only the subject.

- **Nightly** (front-loaded learning; Kaza's call over weekly): if anything was saved,
  the AI distills coaching, approvals, clears (light signal) and spam into
  `learned/answering.md` and `learned/screening.md` in private uploads (code is
  read-only on Pantheon test/live). Bounded notes, no links, team wording kept for
  facts.
- **A test set is the gate:** about 12 cases checking behavior (right figure + source,
  off-topic refused, unreleased data not cited even for "I'm the owner", advisor offered
  for business problems). New notes are kept only if all pass; otherwise roll back and
  email us. It also runs weekly on its own. Test runs must not log to the audit.
- Hard rules (sources only, the release gate) stay in code; notes can't loosen them.

## 7. Placement

A button in the main menu beside the primary call to action ("Find your advisor"),
same color and visible height, close gap (they share a job). Phones: the pair at the
end of the off-canvas menu, chat first to match desktop order. Check every breakpoint
in both orientations; see
[foundationpress-portrait-header](../../memory/wordpress/foundationpress-portrait-header.md)
for a theme bug that surfaced here.

## 8. Deploy

- Secrets in Pantheon Secrets (site-level base = our dev key, live override = the
  client's key; test on our account so the client isn't billed). The client owns the
  live AI account; email them the setup steps.
- Vendor OAuth is authorized **once per environment** at a callback URL that must be
  registered exactly. Activate the plugin per environment (DB), rsync the extracted
  JSON to `files/private/`, import, schedule releases, run the test set there.
- Lock a multidev holding unreleased data. Confirm `.claude/` and private paths aren't
  served (Pantheon returns 404 / 403).
- AI SDK on WordPress: [anthropic-php-sdk-wordpress](../../memory/chat/anthropic-php-sdk-wordpress.md).

## Corrections from the first build

- Keyword retrieval picked the profitability question for "financial future". Fixed by
  the catalog screen; caught by running real questions, which is why the test set exists.
- The cache keyed on screen terms never hit (terms drift); keyed on picks it did.
- A small-company question hit a general cached answer until the screen was told to
  select breakdowns for named company types.
- **Releasing a year broke the test set, and nothing noticed for a week.** Undated test
  questions get the newest released year, so EM's 2025 figures (87%, 80%) failed once 2026
  (88%, 81%) released, which also blocks nightly learning. Updating the test figures is
  part of every release. Pin historical checks to a named year ("In 2015, …") and assert
  that year's source label, so they don't move.
- **The survey-pick cap has to grow with the years loaded.** A cap of three made "how has
  confidence changed since 2015?" cite 2026/2025/2022 and drop the year the reader named.
  Raised to six, and the screen is told to take the same question from each year for a
  trend, always including the earliest and latest. Each extra year also grows the catalog
  (EM, five years: 274 lines, ~10k tokens to the screen per question); prompt-cache it if
  volume makes that matter.
- **Old reports parse with the same code; only the column map is new.** EM's 2015, 2018
  and 2022 Meeting Street crosstabs extracted with the 2025 parser unchanged. Write
  `columns.json` from the header's bottom-line words *in order* (word positions drift a
  column; order doesn't), then prove each label: a banner column's base n must equal the
  TOTAL-column count of the answer it represents. Ran the tests with the years loaded but
  hidden first: they must fail ("cannot answer") before they pass, or they test nothing.
- **A position-read row was "verified" and was a column off.** EM's 2018 Q40 row was checked
  by eye, called correct, and found shifted a column a week later when 2019 hit the same
  bug. Cause: a label wider than the label column ran past the cut, so its underline's last
  dash read as a `-` value (25 tokens, 24 columns) and every answer was stored clipped
  ("LESS THAN 1" for "LESS THAN 10%", in every year). Fix: never split a word at the cut.
  Check a position-read row by comparing the stored values per segment against the printed
  row; don't eyeball it. And re-extract every year after a parser change and diff the values:
  the years that didn't fall back to position must not move.
- **Reports before ~2013 print a net row once per survey wave** under its heading ("TOTAL
  CONFIDENT", then "JANUARY 5-15, 2010", "DECEMBER 4-15, 2008"). Read naively, the wave date
  becomes the answer and the earlier wave passes as this year's data (EM 2010 read 79% for 78%).
  The first wave is the survey's own; it takes the heading (joined if it wraps over lines),
  and earlier waves are skipped. Watch for answers that look like dates, and for a heading's
  first line going missing: "DO NOT SHIP / INTERNATIONALLY" read as "INTERNATIONALLY 52%",
  which inverts it. Split-sample question codes ("40/41C") were dropped until the pattern took
  a slash.
- **When a client uploads files, compare them by hash to what's already loaded** before
  re-extracting. EM's re-uploads matched byte for byte; one topline went to the wrong year.
  If the client was told to remove what the chat shouldn't have, a missing table is deliberate.
- **Topline formats vary by year:** "Question N" blocks, numbered questions with
  statewide/oversample columns (take the first), and trend tables with one column per
  wave (take the last). Encoding junk (`&`, `$`, `!` or `"` for spaces) cleans with sed. A trend
  topline also holds top-line results for waves you have no crosstabs for.
- **A year with only a topline is still worth loading**: overall figures, no breakdowns. Tag
  each row with its report and tell the model when a question has no breakdowns. EM's chat
  then says "only overall results were published for 2011" instead of inventing a split.
  Pick the year's column by its wave label (the latest wave heading any column), not by
  position: Skip/Total pairs put this year's Skip mid-line, and grids prefix each row with
  its wave. A first row labeled with a wave no column carries ("1/13", "3/12" in EM 2013)
  is a typo for this year. Say so in the report, and confirm it against the summary table.
- **A topline layout bug can load the wrong year's figure with no error.** After a rating
  grid, EM 2011 Q18 was read as a grid item. When it turned out to be a plain question,
  the switch back dropped the wave headings already read, so the line "13% 37% 36% YES"
  loaded 2008's 13% as 2011's and put the rest into the answer text. Guard: two or more
  figures left in front of an answer means a missed header, so skip the line and report it.
  Never let leftover figures become a label. Only the cross-check caught this one.
- **A topline-only year's breakdowns may sit in later reports.** Until 2014, EM's crosstabs
  repeated earlier survey waves for every question they reused, across all their columns:
  inside each table (2010, 2012) or in "Summary of … Trend" tables (2014). Before telling a
  client a year has no breakdowns, grep the later reports for its wave label. Match each block
  to the topline question whose overall figures it reproduces exactly (two answers or more,
  labels compared loosely: "CONFIDENT" is "TOTAL CONFIDENT", "10" is "Rated 10 (most)"). The
  match is also the check. File the rows under the topline's wording and cite the later
  report. EM gained group results for 53, 30 and 27 questions.
- **A later report's groups don't all apply to an earlier wave.** Groups the earlier survey
  couldn't define (newer employee bands it never asked, "status quo" groups built from the
  newer survey's answers) print blank in one report and as figures in another. Compare every
  wave block two reports share, not just the year being loaded. Leave out any group two
  reports disagree on, everywhere, or a year with one source (EM 2013) keeps the bad groups.
  Leave group sizes blank rather than derive them, and rename labels naming the later year
  ("Expects 2010 economy to be").
- **Cross-check a topline by value agreement, not text similarity.** Matching questions by
  wording pairs the wrong ones (2008 "retention factors" vs 2011 "recruitment factors" read as
  dozens of false conflicts). Instead, find the question in the other document whose shared
  answers all carry the same figure. That is a coincidence only with fewer than three
  answers. Sources of a second reading: later toplines' trend columns (read with the wave
  forced), the year's own summary tables (grids' % 10, % 8-10 and mean), and, for the rest,
  a dumb positional read of the raw line scoped to the question's block. Check what's left
  by eye. EM's three years: 1,141 figures, all confirmed, zero conflicts.
- **Measure where the money goes before reaching for a fix.** EM's catalog grew to ~29k tokens
  at 15 years, but on Haiku that's ~0.3¢ a question. The rise in a plain answer from ~1.8¢ to
  ~3.2¢ came from the Opus answer reading real page text once pages were readable: the cost
  of using the content. Prompt caching pays only when requests sharing a prefix start under
  5 minutes apart (1-hour TTL: three or more reads within the hour). At EM's 1–4 questions a
  day every entry would expire and each question would pay the write premium, so it would
  cost more. Revisit when traffic is steady.
- **The first real coaching exposed four gaps, each found by asking the coached questions
  again after learning** (EM, 2026-11-18). Do that every time you touch learning; a passing
  test set doesn't show the coaching took.
  1. *The chat couldn't read the site.* Theme content lives outside post_content: ACF blocks
     keep text in block attributes, and articles and events keep it in meta fields. Every page
     reached the AI as a bare title. Check that a page excerpt has text before trusting page answers.
  2. *The learner didn't know the pipeline.* "Open that year's files" became a note promising
     a search. Tell the learner what the chat can and can't do. It routes lessons to the step
     that acts on them (search wording goes to screening), turns impossible steps into possible
     ones, and lists what it couldn't apply for the team on the report.
  3. *Naming a page doesn't make search find it.* One combined query buried "Deep Dive". The
     screen returns `page_titles` a note names, fetched directly (ignore ®/™) and keyed into the cache.
  4. *A fact in a note loses to "answer only from sources".* Team-stated facts are their own
     list, served as a citable source ("Enterprise Minnesota team"). A figure without a survey
     source passes only if it appears word for word in a cited page or fact.
  Also: retry a failing test case once (one screen miss rolled back a night's learning), and
  have the learner rewrite old notes that predate its current rules.
- A refresh token was printed into a session log by a diagnostic call. Never echo
  token-bearing API responses; revoke and re-authorize before launch if it happens.

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
- A refresh token was printed into a session log by a diagnostic call. Never echo
  token-bearing API responses; revoke and re-authorize before launch if it happens.

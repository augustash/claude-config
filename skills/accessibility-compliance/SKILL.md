---
name: accessibility-compliance
description: Establish what accessibility law requires of a client's site, measure the site against it criterion by criterion, rank the plan by those rules, and present it in the client record with a "Your requirements" page written for that site. Use whenever a client's accessibility standing, plan or recommendations are being reported: every POM+ quarter, a client asking "are we compliant?", or a public body facing a deadline. Pairs with accessibility-audit, which finds the defects; this skill decides what they're measured against and in what order to fix them. NOT for finding defects (that's accessibility-audit), not legal advice, and never a score.
---

# Accessibility compliance

A client wants to know what they're required to meet and whether they meet it. This skill
answers that from the law itself, site by site, and turns the answer into the order we fix
things in. Established on metroairports.org (2026-10-23); its record is the reference
implementation (`metro/.claude/docs/pom/`).

**Every client is its own requirement.** There is no default standard to measure against.
Who the client is (a government body, a business open to the public, an employer or a union, a
federally funded program) and what their site does decide which law reaches them, which pages
weigh most, and whether there's a deadline. Find out what applies to *this* client before
measuring anything (Kaza, 2026-10-24).

**Our goal is to help them meet it.** The goal bar, the path of items and Reach goal all point
at the client's requirement, not at a generic score or at WCAG for its own sake. When the
requirement exempts something, it drops out; when it weighs something heavily, it leads.

**The rules govern the plan.** Not a vendor score, not the count of findings, not what was
easiest to find. Whatever the rule exempts drops out; whatever stops someone finishing a task
comes first. Kaza: *"we need to actually understand the rule. Then we can meet it."*

---

## 1. Find the client's rule set

Which law applies depends on who the client is. The table is where to start looking, not a
lookup: a client can sit in two rows (a union that also runs a training program open to the
public) or in none. When none fits, research what does and write it as a set per §2.

| Client | Rule set |
|---|---|
| State or local government body (agency, authority, commission, school district) | ADA Title II web rule, [ada-title-ii-web-rule](../../memory/accessibility/ada-title-ii-web-rule.md) |
| Private business open to the public | ADA Title III. No web regulation: courts use WCAG 2.1 AA as the yardstick. **Not yet written as a set**; write it per §2 before using it |
| Federal agency or federally funded program | Section 508 / Section 504. **Not yet written as a set** |
| Labor organization (union), or an employer's hiring and job pages | ADA Title I, which covers a union's membership, training and job referral, plus any state human rights law that reaches the same activities. No web regulation and no deadline; WCAG 2.1 AA as the yardstick. **Not yet written as a set** |

A rule set is a **living memory**: it carries `reviewed:` and `review_every_days:` in its
frontmatter, and the SessionStart audit hook flags it when it's due. On review, re-read its
sources for amendments and rulings, update it, bump the date. Client pages are built fresh
from it every round, so a ruling change reaches the next record on its own.

## 2. Establish, never guess

Every statement that reaches a client traces to the regulation, the WCAG text, or the
regulator's own published explanation (for Title II, the 2024 rule's preamble). When the rule
text doesn't settle a question, **find the definition** before writing anything, and record
it in the rule-set memory with the quote:

- The preamble answers most questions. For Title II: `curl` the govinfo PDF, `pdftotext`
  without `-layout` (the Federal Register's three columns interleave otherwise), grep.
- eCFR and federalregister.gov block automated fetches; Cornell LII serves the current CFR
  text (check its amendment line for the latest change).
- Secondary commentary (law-firm alerts, vendor blogs) disagrees on several points and is not
  a source. On 2026-10-23 a university summary claimed an "ongoing duty" the cited source
  didn't contain; it stayed out until the preamble supplied the real text.

Established so far (Title II): what "otherwise secured" means (a sign-in or authentication is
required, so a public file address doesn't qualify however unguessable), and that staff-only
content is not exempted. Both quoted in the memory.

## 3. Gather the site's facts

Only facts that change what the rule asks of *this* site. Two sites of one client can differ
completely. Collect:

- **Vendor tools carried under contract**: chat, marketing pop-ups, meeting portals, job
  boards, maps, booking. The rule covers what the client provides "through contractual,
  licensing, or other arrangements", so these count against the site. Name them.
- **Documents**: count PDF/Word/slide/spreadsheet files
  (`file_managed` by extension, and the site's document content type), then find the ones
  still used to apply for or take part in something: search titles for *application, form,
  permit, request, agreement, complaint*. Those stay covered; the rest are usually exempt.
- **Archive candidates**: old news, reports, past events that a clearly marked archive would
  take out of scope (Title II's archived-content exception has four conditions; all must hold).
- **What sits behind a sign-in**, and whether "secured" documents really require one.
- **Its deadline**: the client's bucket under the rule set. If the bucket is a legal call
  (Title II special district vs instrumentality), give both dates, say counsel confirms, and
  plan to the earlier one.

## 4. Mark every criterion

WCAG 2.1 AA is 50 criteria (30 A, 20 AA). Give each one a status from the verified findings
of the [accessibility-audit](../accessibility-audit/SKILL.md) pass:

- **Supports**: met on every page tested.
- **Partially supports**: met in places; say where it fails.
- **Does not support**: not met wherever it applies.
- **Not applicable**: the site has nothing it covers.
- **Not yet tested**: the audit didn't reach it. **Never mark a criterion met without
  testing it.** The untested set is next quarter's scope.

Remarks are one line each, in the client's words, naming where. Keep the data as a list
(criterion, name, level, status, remark) so the table and the counts come from one source.

## 5. Rank by the rules

In this order:

1. **Exempt content drops out** of the plan entirely.
2. **What stops someone finishing a task** comes first. Under Title II this is § 35.205's
   minimal-impact test: a shortfall is tolerated only if people with disabilities can still
   get the same information and do the same things with equivalent timeliness, privacy,
   independence and ease. A permit form a screen reader can't read fails it outright, so on
   metro the covered documents outranked every page fix.
3. **Reach**: fixes that apply across many pages before ones that touch a few.
4. **The deadline sets the pace**: the year plan must reach all-Supports in time.

The ranking is ours to explain, not hide: the client page ends with it (§6).

## 6. The "Your requirements" page

A short page about this site only, assembled from the block library
`templates/client-report/accessibility-rules.html`. Each block says when it applies; include
only those, filled with §3's facts. Never the whole rule: Kaza, *"there is no reason to provide
them a massive document where 90% doesn't apply to them."*

Typical blocks: the requirement and its date · the vendor tools it covers · which documents
are still covered · an archive option · how we weigh findings · how we report · **how this
shapes our plan** (the §5 order, in plain words) · a one-line "not legal advice".

It lives in the record as a full-screen `<dialog class="rules">`: a light page with the POM+
pattern bar on top and a Close button at the upper right; Escape closes it. It opens from a
**"Your requirements"** button at the upper right of the Accessibility section, beside its
Close. Print hides it.

## 7. How it shows in the record

Inside the Accessibility section (POM+ bar, see client-report):

- **A requirement block first**: the standard, the deadline, what's exempt in one sentence,
  and a status bar across all 50 criteria with counts (Supports / Partially / Does not / N/A /
  Not yet tested).
- **Then the write-up**, terse, ending on the order ("ordered by your requirements").
- **Each Work item names the criteria it moves**: *Meets 2.2.2* or *Moves toward 1.3.1,
  2.5.3 and 4.1.2*. A scoping item says so (*Sets the scope for documents under the rule*).
- **"All 50 criteria"** at the end, collapsible: criterion, status chip, where it stands.

### The goal

The plan is a route to the requirement, so the record shows where the goal is and what reaches
it (Kaza, metro 2026-10-23):

- **The list is the whole path, not one quarter.** Every fix needed to clear every known
  failure, in §5's order. The build must check that each failing criterion is covered by an
  item above the line, or the line is drawn somewhere the items don't reach.
- **A goal bar** at the top of the Accessibility section: thin, full width, filling red to green
  (the gradient spans the track, so the fill shows the colour of where it has reached).
  *15 of 26 tested criteria met · Goal: all 26 (19.5 hrs) · 20 more to test*. Count against
  *tested* criteria, so it never claims what hasn't been checked.
- **Approving projects the outcome.** A lighter fill shows where approved items land; a
  criterion counts once every item that fixes it is approved (each item carries `data-sc`).
- **A green band behind the items that reach the goal**, the full width of the panel, marked at
  the top ("To the goal · these items get you there") and bottom ("Goal · every criterion
  we've tested, met (N hrs)"). Items past the goal stay in the same list, below the line; the
  line is what separates them, not a heading.
- **Reach goal** beside the bar, with the approximate price: one click selects every item to
  the goal, and again clears them.

## 8. Vendor scores are a second line, at most

When the client uses Siteimprove or similar, its number is what their team is graded on, so
it can sit beside ours. But it is not the requirement:

- Siteimprove scores per rule, not per occurrence: a rule cleared everywhere earns its share
  (1.58 points on mspairport.com), partial progress barely moves it. Fixing focus on most of
  a site moved the score 0.01.
- Its formula isn't public and a plain average doesn't reproduce it; don't try. Use the gains
  it states itself ("Fix this issue and reach N points").
- It can't see interaction barriers. MSP's three worst findings (airline filter, language
  list, phone flight board) don't register at all. Say "not measured by Siteimprove" rather
  than implying they don't matter.

## 9. Pricing

Quote on the tooling and experience, not the keystrokes
([quote-the-tooling](../../memory/pricing/quote-the-tooling.md)). Agents' per-item estimates
are keystroke estimates; adjust before they reach a Work row.

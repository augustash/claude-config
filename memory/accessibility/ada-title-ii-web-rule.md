---
name: ada-title-ii-web-rule
description: What the ADA Title II web rule actually requires of a public-entity client, read from the regulation; the basis for reporting their standing.
metadata:
  type: reference
  reviewed: 2026-10-23
  review_every_days: 30
---

# ADA Title II web rule (28 CFR 35, Subpart H)

Read from the regulation itself (28 CFR 35.104 and 35.200–35.205, as amended by the interim
final rule of 2026-04-20, 91 FR 20912), on metro 2026-10-23. Not legal advice; the client's
counsel decides which provisions they rely on.

**The requirement (§ 35.200).** A state or local government entity must make the web content
and mobile apps it provides, *directly or through contractual, licensing, or other
arrangements*, comply with the **Level A and AA success criteria and conformance
requirements of WCAG 2.1**. That is 50 criteria (30 A, 20 AA). Vendor embeds the client
places on its site (chat, marketing pop-ups, meeting portals, job boards) are theirs to answer
for.

**Dates (after the 2026 extension):**
- **2027-04-26**: total population ≥ 50,000, other than special district governments.
- **2028-04-26**: total population < 50,000, and every **special district government**
  (created by state law for one or a few functions, autonomous enough to be a separate
  government, no Census population of its own). An *instrumentality* of a state or local
  government instead takes that government's population. Which one a client is, is their
  counsel's call. Advise planning to the earlier date.

**It is not a score.** WCAG conformance is per *page*, judged on the whole page, and a
multi-step process conforms only if every step does. Vendor scores (Siteimprove's DCI and
"site target" percentages) are proxies; no threshold in them is the legal test. The standard
way to report standing is an **Accessibility Conformance Report** (ITI's VPAT template): each
criterion marked Supports / Partially Supports / Does Not Support / Not Applicable, with
remarks. Add "Not yet tested" for anything an audit didn't cover, rather than implying it
passes.

**Exceptions (§ 35.201)**, which shrink the scope:
- **Archived content** made before the deadline, kept only for reference, never updated, in
  an area clearly marked as archived.
- **PDFs, Word, slide and spreadsheet files posted before the deadline**, unless currently
  used to apply for, gain access to, or take part in a service. On a document-heavy site
  (metro: ~1,560 PDFs) this is the biggest scoping lever: old agendas and reports are out,
  a live application form is in.
- **Third-party content**, unless posted under contract with the entity.
- **Individualized, secured documents** about one person.
- **Social media posts** from before the deadline.

**Relief provisions:**
- **§ 35.202** conforming alternate version: only where direct access is technically or
  legally impossible.
- **§ 35.203** equivalent facilitation: other techniques are fine if at least as accessible.
- **§ 35.204** undue burden or fundamental alteration: needs a written decision by the head
  of the entity, and everything short of the burden must still be done.
- **§ 35.205** minimal impact: noncompliance is deemed compliant if the entity can *show* it
  doesn't stop disabled users getting the same information, interactions, transactions and
  services with substantially equivalent timeliness, privacy, independence and ease of use.
  This is where severity lives legally: a blocked task fails it, a cosmetic slip may not.

**Living document.** Client records build their "How we judge accessibility" page from this
memory and the block library in `templates/client-report/accessibility-rules.html`, so keep it
current: the SessionStart audit hook flags it every 30 days. On review, check the Federal Register
and ADA.gov for amendments to Subpart H and any change to the WCAG version it names, update this
file, and bump `reviewed`.

**How to apply:** report a public client's accessibility as the ACR-style criterion table
plus the deadline, name the exceptions that apply to their content, and judge each finding
against § 35.205. The accessibility-audit skill's method produces the findings; this is what
they are measured against.

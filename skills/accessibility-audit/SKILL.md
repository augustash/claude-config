---
name: accessibility-audit
description: Test a site's accessibility and produce a defensible record of what was found — for an ADA demand letter or lawsuit, a client asking "are we compliant?", a pre-launch check, or a VPAT/remediation scope. Covers the layered method (rule engine, structural checks, real screen-reader output), the traps that produce false findings, and how to attribute third-party defects. NOT for fixing one known accessibility bug you have already identified — just fix it. Not a substitute for testing with an actual screen-reader user.
---

# Accessibility audit

A method for finding real accessibility defects, proving them, and writing them
down in a form that survives someone hostile reading it. Built on the sisalrugs.com
response to an Equal Access Law Group demand (August 2026).

**We use the best engines available and own the method around them.** axe-core is
the industry rule engine — Lighthouse and most commercial scanners run it
underneath — and Guidepup drives real assistive technology. Neither gets rebuilt.
What does not exist off the shelf is the orchestration: rule scan plus structural
checks plus screen-reader transcripts, dated and reproducible. That is this skill.

---

## 1. Establish what you are answering first

**A demand letter is a specification.** Read it before testing anything and pull
out the exact URLs, components and behaviours alleged. Test those first, by name,
and report on them item by item. A site-wide scan that never addresses their
Appendix A does not answer the letter, however thorough it is.

Expect the allegations to be a mix of **accurate, overstated, and misdirected** —
all three appeared in one three-item appendix. Test each on its own merits:

- One was **true and worse than described** (fields alleged to have vague labels
  had no accessible name at all).
- One was **substantially overstated** (a claimed pattern of duplicate links was
  one instance per page).
- One was **real but on a different page** than the one cited, and turned out not
  to fail any specific success criterion.

Saying so precisely is worth more than agreeing with everything. It shows the
testing was real.

**Establish the client's actual scope early.** Public-facing pages, authenticated
areas, admin? It changes the page list and what you recommend. Don't assume.

---

## 2. The layers, and why each one is there

Run all four. Each catches a class the one above it structurally cannot.

| Layer | Catches | Cannot catch |
|---|---|---|
| **axe-core rules** | Missing labels, contrast, ARIA misuse | Anything requiring judgement about *meaning* |
| **Structural checks** | Duplicate tab stops, clipped-but-exposed carousel content, focus-indicator absence | Whether the announced text makes sense |
| **Screen-reader output** | Alt text that exists but says nothing; a field named by its value; a legend that never reaches the input | Whether a real user could actually complete the task |
| **A screen-reader user** | Everything else | — |

**Automated rules detect roughly 30–40% of accessibility issues.** State this in
any document you produce. A clean scan is not evidence of an accessible page, and
implying otherwise is the fastest way to lose credibility with anyone who knows
the field.

**The screen-reader layer earns its place immediately.** On sisalrugs the rule
engine passed every product image — `alt` was present. Listening to the output
gave `link, Create A Brasilia Sisal Rug - Ash Wdes-silver.jpg`. The attribute was
there; the text was a filename. No rule can catch that, and it is a Level A
failure.

### Running the layers

Templates live in [`templates/a11y/`](../../templates/a11y/):

- [`audit.mjs`](../../templates/a11y/audit.mjs) — axe plus structural checks, config-driven, all pages × viewports → `audit.json`
- [`virtual-screenreader.mjs`](../../templates/a11y/virtual-screenreader.mjs) — headless announcement capture, no permissions needed; `--compare` for before/after
- [`screenreader.mjs`](../../templates/a11y/screenreader.mjs) — real VoiceOver/NVDA via Guidepup

```
npm i playwright axe-core @guidepup/virtual-screen-reader @guidepup/guidepup
npx playwright install chromium
```

**Real-AT automation costs a permission expansion, and the virtual reader usually
is not worth trading it for.** Establish this with the user before spending time on
it. What driving real VoiceOver on macOS actually requires:

1. `npx @guidepup/setup setup` — note the doubled word; the package is
   `@guidepup/setup` and `setup` is its subcommand.
2. `npx @guidepup/setup install voiceover` — installs the preferences bundle. Easy
   to miss, and skipping it fails later with a misleading message.
3. Accessibility permission for the host terminal (System Settings → Privacy &
   Security → Accessibility).
4. **Write access to `~/Library/Group Containers/group.com.apple.VoiceOver/`** —
   Guidepup mounts a preferences DMG and symlinks into it. That path is
   TCC-protected, so this is the step that actually blocks.

Running `setup --macos-ignore-tcc-db` to avoid touching the privacy database
leaves step 4 failing with `EPERM ... symlink`. The honest choices are Full Disk
Access for the terminal — permanent and broad, every process in that terminal
gains read access to all user data — or letting the tool edit the TCC database
itself. **Neither is yours to decide.** Put the trade to the user and let them pick.

**When VoiceOver "cannot be started", read `error.cause`.** The thrown message is
generic; the real reason is two levels down the cause chain. Walk it before
diagnosing anything.

**Weigh it honestly before asking.** NVDA and JAWS on Windows are what roughly
65% and 60% of screen-reader users run; VoiceOver is under 10%. A macOS-only
real-AT pass is not the representative case it sounds like, and the virtual reader
already produces genuine announcement sequences. On sisalrugs the virtual reader
supplied every transcript in the report and found the filename-alt-text defect;
real VoiceOver was scoped out and nothing was lost.

**Starting a screen reader hijacks a machine someone else is using.** It speaks
aloud through the active output device and captures the keyboard. On sisalrugs it
started reading during a call the developer was on — "sound is off" is not
protection, because a call routes audio separately and screen sharing carries it.

So permission to set the tooling up is **not** permission to start it. Get an
explicit go-ahead for the *moment*, immediately before each run, and treat any
gap — a call, a demo, someone else at the keyboard — as a stop. Never start one
mid-diagnosis to test a hypothesis; that is exactly how it gets started five times
in ten minutes.

Stopping it is harder than starting it. `osascript ... quit` and `killall
VoiceOver` both reported success and left it running; only
`pkill -9 -f "VoiceOver.app/Contents/MacOS/VoiceOver"` worked. Put that in a
`finally`, run it even on the paths that "cannot" have started it, and verify with
`pgrep` rather than trusting the stop call.

To leave a machine as you found it: `pkill` the process, then
`defaults delete com.apple.VoiceOver4/default SCREnableAppleScript` so nothing can
start it programmatically again, and drop `~/Library/Caches/guidepup`. The
Accessibility permission granted to the terminal can only be revoked by the user.

**Scope the reader to one component when comparing.** A whole-page read is
hundreds of lines and diffs badly. Scoped to the disputed fieldset, the before and
after fit side by side and the change is self-evident:

```
textbox, 2, required            →  textbox, Width in feet, 2, required
textbox, 0, required            →  textbox, Width in inches, 0, required
```

That pair of lines did more work in the report than any amount of description.

---

## 3. Traps that produce false findings

Every one of these produced a wrong reading that nearly reached a client document.
**A finding from an automated sweep is a lead, not a fact.** Verify before writing.

**Never detect keyboard traps by text signature.** Matching on tag + class + text
flags two third-party widgets that share a label as one element capturing focus.
Stamp every element with a unique id and track *identity*: 88 tab presses reaching
87 distinct elements with nothing focused twice is a clean result. The first pass
reported a trap; there was none.

**Check ancestor visibility before measuring geometry.** A carousel inside a
`display:none` wrapper has a zero-width container, so every slide computes as
"outside the visible area" and you report hundreds of characters of exposed hidden
text that no assistive technology can reach. Walk up for `display`, `visibility`
and `aria-hidden` first; bail out on a zero-width container.

**Settle the page twice before counting anything.** One fast scroll pass leaves
lazily-built regions unrendered — 85 links versus 328 on the same page. Every
count taken too early is low. Two slow passes plus a multi-second wait.

**Counts taken mid-initialisation are not real.** A duplicate-tab-stop count of 33
dropped to 1 once page scripts finished and navigation panels collapsed. If a
number changes between runs, you measured a transient state, not the user's
experience.

**Compare link destinations by origin + pathname.** Exact-href misses links
differing only by a query string (`?color=beach`); pathname alone makes every
off-site share link resolve to `/` and collide. Both errors were made in one
session, in opposite directions.

**Use one focus-indicator definition and stick to it.** A control may indicate
focus by border or background, not outline. Comparing computed style against an
unfocused clone of the same element is the reliable test; checking only
`outline`/`box-shadow` produces false positives. Two scripts using two definitions
will disagree and waste a round.

**Not every reported behaviour is a conformance failure.** Off-screen carousel text
being read is a genuine annoyance and fails no WCAG 2.1 AA criterion — the content
is present and correctly ordered. Say "assessed, not a failure, here is the
mechanism" rather than either dismissing it or inflating it. That distinction is
exactly what a client's counsel needs.

---

## 4. Attribute honestly

**Separate what we control from what we do not.** On sisalrugs a large share of
violations came from injected vendor scripts — ConvertCart recommendations
(`button-name`, much of `image-alt`), Klaviyo, Affirm, LiveChat, and slick's own
list markup. Report per-row ownership rather than one aggregate figure that
overstates what a remediation can reach. Where a vendor is the source, the honest
options are: press them, reconfigure, or replace.

**Watch for third-party noise that mimics a real defect.** Klaviyo ships
permanently-empty `role="alert"` nodes that are present on page load. They look
exactly like a broken validation region. Confirm an empty alert is the platform's
before chasing it.

**Bot protection blocks scanning, and that is a limitation, not a pass.** Cloudflare
returned 403 to the automated browser on `/user/register`. Say the page was not
scanned rather than omitting it.

---

## 5. Root-cause rather than symptom-fix

Two failures with one cause is common, and finding it makes the remediation far
more defensible than patching each surface.

The canonical example: a `#required` Drupal element with no `#title` has no
accessible name *and* produces an empty validation error, because core cannot build
the message string without a title — and core's own source comment prescribes
`#title` plus `#title_display: 'invisible'` as the fix. One line closed a 4.1.2
failure and a 3.3.1 failure. See
[[form-element-title-drives-error-message]].

When you can cite the framework's own documentation for the remedy you applied, do
— it converts "we changed something" into "we applied the documented fix".

---

## 6. The document

**Deliverable shape is [client-report](../client-report/SKILL.md)'s job** — one
self-contained branded HTML file, brand colours pulled from the client's own theme
variables, sticky section nav, integrity-checked. Don't re-derive it here. What is
specific to an accessibility record:

**Say what it is and is not, at the top.** A technical record of what was tested
and found; not legal advice, not a certification, no opinion on the merits. No
accessibility test can establish a site is free of barriers.

**Per reported item, record all of:** page/URL, component, method, browser and
assistive technology, whether it currently reproduces, what change addressed it,
remaining concerns, and the date. That list usually comes straight from the
client's request — follow it literally so the answer is checkable against the ask.

**Publish your own corrections.** The report says a keyboard trap was flagged and
then disproved, and that an early duplicate-link count was unrepresentative.
Including a correction you caught yourself is stronger than a clean narrative,
because it shows the numbers were tested rather than collected.

**Record what was fixed and note it is not live until deployed.** A verified fix on
a development build protects nobody. State the deployment dependency explicitly.

**Warn against accessibility overlays, in writing.** A business that has just
received a demand letter is a target for vendors selling accessiBe, UserWay or
AudioEye as instant compliance. Overlays do not remediate the underlying markup,
are rejected by the accessibility community and by screen-reader users, and sites
using them have continued to be sued. This is the most likely expensive mistake
available to the client at that moment, and it costs one paragraph to prevent.

**Retain the harnesses with the results.** Ship the scripts alongside the JSON so
every figure can be re-run rather than taken on trust, and so re-running after
deployment produces a dated "after" record that pairs with the "before".

---

## 7. What this cannot do

Be honest about the ceiling. Automated and scripted testing establishes what the
markup does. It does not establish that a person can complete a task. An
experienced screen-reader user navigates by rotor, headings list, landmarks and
form mode — not linearly — and will find things no script reaches. Recommend a
session with an actual assistive-technology user, and do not let a clean set of
numbers imply it is unnecessary.

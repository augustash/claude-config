---
name: client-proposal-review
description: Analyse a client's proposed decisions — a menu reorganisation, a design round, a feature list, a "can we add X" — and counter where needed, shipping it as a short self-contained HTML document. Use when a client hands over a structure or a set of choices and we have to steer them off the parts that would make the site worse without losing the parts that are right. NOT for a rebuild pitch or an evidence-led audit (that's client-report), and NOT for a tracked punch list of open items — this is one topic, and it ends the discussion rather than opening a queue.
---

# Client proposal review

The document we send when a client has decided something and some of it is wrong.
Refined on the DMX Power menu reorganisation.

The job is **control without a fight**: adopt everything defensible, refuse the small
number of things that would do damage, and make saying yes to our version easier
than defending theirs.

---

## 1. Ground it before you argue it

**Map every item they proposed onto what is actually built, before writing a word of
the document.** Open the builders, the config, the taxonomy. This is the whole game:
it converts "we don't like this" into "here is what that maps to today, and here is
what changes" — and the client's own site becomes the authority rather than our taste.

It also catches the items where *they* are right and we assumed otherwise. On DMX, the
proposed Products column looked like it mixed a catalog with a tool and a programme;
grounding it showed the two moves emptied About of both its children, which is exactly
why they had marked About as one page. Their structure was more coherent than the first
read suggested, and the document said so.

**Verify every claim you make about their content, including the ones you are confident
about.** These documents argue from specifics, and the specific is usually better than the
one you half-remembered. On DMX the draft said a video section "has the written steps
beside each video" — true, but opening the builder showed each walkthrough carries a full
written procedure, and that the single most important item in the section is a warning that
equalizing the wrong battery chemistry causes permanent damage. Text, not video. The
verified version won the argument the assumed version only gestured at.

**Establish the deployment state before you argue cost.** Half a set of objections can
evaporate on one fact. On DMX the renames looked expensive — derived anchors, a redirect
map, cross-links — until the client-side reminder that the site is still on dev and
nothing external points anywhere. Every reference was in files we own; the cost was a
find-and-replace. *Ask whether it's live before pricing a change as breakage.* An
objection that dissolves under one question costs credibility on the objections that
survive.

---

## 2. Count the ratio, and say it first

Tally the verdicts before you write: adopt / rename-only / rework / advise-against.
**State the tally in the opening paragraph.** "Most of it we'd build as drawn; we've
pushed back on two of six" reframes the entire document from obstruction to
collaboration, and it costs two sentences.

**If you are refusing more than about a third, stop and re-read your own reasoning.**
That ratio usually means the review has drifted into taste. Refuse things that would
damage the site; concede things that are merely not how we'd have done it.

**Separate the free concessions from the expensive refusals, and give the free ones
away explicitly.** Something that costs nothing *and is no worse* should be handed over
in as many words — "that's yours to call, say the word." It is worth more than it costs:
it establishes that the refusals are about consequence rather than preference, and it
leaves one argument to spend capital on instead of four.

⚠ **Cheap to implement is not the same as free.** A rename costs nothing to build and can
still be a worse label, and conceding it trades the site's quality for goodwill we did not
need to buy. On DMX the instinct was to hand over Support → Help Center because no code
depended on it; the correct read was that "help" describes less than "support" for a
section carrying fault codes and service documentation, "Center" is doing no work, and the
result is longer and less common than the word it replaces. **Test the concession on
merit, not on effort** — then concede the ones that genuinely are neutral, which makes the
one you argue look like judgement rather than reflex.

---

## 3. Every counter names the goal behind their item

**Never refuse a request without identifying what it was for.** A client asking for the
wrong thing is nearly always asking for the right thing badly, and the intent is the
part worth agreeing with out loud.

The DMX Document Library column duplicated the catalog. The paragraph that does the work
is not the one explaining the duplication — it's the one before it: *documents should be
easy to find, and for products like these they are often the reason someone visits at
all; our concern is that this moves them further away.* Then the mechanics land as help
rather than correction.

**Convert the refusal into a request of them.** If the concern behind the column is that
documents are hard to find, ask for the list of models whose documents are missing or
wrong. They get the outcome they wanted, we get a content pass instead of a nav change,
and the column dies without anyone defending it.

**Distinguish "we disagree" from "we cannot map this."** A genuine unknown is a question
and must be dressed as one — assume it is deliberate and ask what they meant. Dressing a
question as a pushback insults a decision they may have reasoned carefully; dressing a
pushback as a question loses the argument you needed to win.

**Flag what their structure has no place for.** The thing they forgot outranks the thing
they got wrong: it is not a criticism at all, it is us catching something, and it is the
item most likely to make them trust the rest. On DMX the permission-gated dealer section
had no home in the proposed menu — *and* could not be an ordinary menu row, because the
row would show to everyone while its contents did not.

---

## 4. Close with the resolved structure

**End on a concrete counter-proposal, not a list of questions.** This is the control
mechanism. A question list hands the next move back to the client and reopens everything;
a resolved structure that visibly absorbs their columns is a thing to approve. Keep their
labels wherever the label wasn't the problem — the document should read as their proposal
refined, not replaced.

Leave open only what genuinely needs their answer, and make each one a single decision
with the options named ("one row that lands on the full map, or four pre-filtered rows?").

---

## 5. Tone scales with what they invested

**Ask how much work went into it before choosing a register.** A first sketch takes
directness; a set of decisions they laboured over takes the intent-crediting version of
every counter, or the document lands as a week of their work being marked. The content
does not change — the ordering and the framing do.

Watch the two-word verdicts hardest. In a scannable readout they carry more weight than
the paragraph they summarise: "Recommend against" reads as a ruling, "We'd advise
against" as counsel. Same position, and the second one survives contact with someone
who is proud of the column.

Never characterise the proposal as a whole. No "this is confusing", no "several of these
are worse". Every criticism attaches to one named item and carries its alternative.

---

## 6. What this document is not

Two different things get confused with this one. They are unrelated to each other, and
both are unrelated to this.

- **Not a rebuild pitch or an audit.** [client-report](../client-report/SKILL.md) is the
  genre where we tell a client what we found and sell what we would do about it —
  masthead, five-things-that-matter, why-this-team, why-this-is-the-moment. Borrowing
  that scaffolding here reads as padding on a two-page reply, and the persuasion
  machinery is aimed at a decision the client has not been asked to make.

- **Not an entry in the project's own client report.** A long-running project usually
  keeps one: a standing list of rebuild items the client is working through, with ids,
  carry-forward and its own ledger. That artifact tracks the rebuild. This document
  answers one proposal and closes. Do not file this into it, do not number these items
  against it, and do not mine it for evidence — its findings belong to a different
  conversation, and pulling them in turns a focused reply into a queue.

**And not a punch list of its own.** One topic, no ids, nothing to carry forward. It
ends the discussion rather than starting a tracked one.

## 7. Output

**One self-contained HTML file, in the project's `docs/`.** Same contract as
[client-report](../client-report/SKILL.md) §5 — real `<!DOCTYPE html>`, `<meta charset>`,
viewport, system fonts only, zero external references. Verify with
`grep -oE '(src|href)="[^#][^"]*"'` returning nothing.

**Pull the palette from the client's own theme**, not from memory. On a Neo site the
ramps are in `config/neo_color.neo_pallet.*.yml`; primary and secondary are the brand.
Respect the project's own colour conventions if it has them — a decorative step is often
not a legible text step.

Keep it to one screen of real content per section and no more than about six sections.
The whole point is that it can be read before a meeting rather than after it.

**A status readout near the top earns its space.** One row per item they proposed, with a
colour dot and a two-word verdict, in mono. Six verdicts become a two-second read, and it
sets the ratio from §2 visually before the prose argues it.

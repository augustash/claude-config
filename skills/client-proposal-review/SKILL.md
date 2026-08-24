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

**Pre-empt the halfway version.** A client whose structure you refuse will reach for the
compromise rather than the reversal — "fine, make the library searchable", "fine, keep it
but move it". A counter-proposal that only answers the original reopens the argument one
mail later, on ground you have not prepared. Name the likely compromise and answer it in
the same breath: on DMX, a searchable document library is the same answer with extra steps,
because the site already has a search and a second one splits the thing a library was meant
to fix. Say it while you have their attention, not after they have proposed it.

**Distinguish "we disagree" from "we cannot map this."** A genuine unknown is a question
and must be dressed as one — assume it is deliberate and ask what they meant. Dressing a
question as a pushback insults a decision they may have reasoned carefully; dressing a
pushback as a question loses the argument you needed to win.

**A label is a container — test it against everything the section must stay true of.**
Clients rename toward specificity, and specificity in a label is a constraint rather than a
gain: the narrower name is only right if it covers every item in there today *and* whatever
plausibly gets added. DMX proposed two renames with exactly this shape — Guides to How-to
Videos, on a section whose written procedures are the substance, and Learn to Power Theory,
on a section that is seven articles in two groups where the second group is a purchase
decision, an installation procedure and a guide to satisfying an electrical inspector.

**Make it arithmetic, not taste.** "Accurate for four of the seven, wrong for the other
three, including a step-by-step installation" ends the argument. "We prefer Learn" invites
a counter-preference. Go and count before you write the paragraph; the count is the
argument.

**Argue inside their rationale, not against it.** Ask why they name things the way they do,
because a stated reason is the strongest lever you will get. DMX picks section labels to be
accurate for search indexing — which turns an over-specific label from a matter of taste
into something that actively works against a goal they already hold. A client will drop a
name to protect their own reasoning far faster than to accommodate ours.

**Flag what their structure has no place for.** The thing they forgot outranks the thing
they got wrong: it is not a criticism at all, it is us catching something, and it is the
item most likely to make them trust the rest. On DMX the permission-gated dealer section
had no home in the proposed menu — *and* could not be an ordinary menu row, because the
row would show to everyone while its contents did not.

---

## 4. Lead with the resolved structure

**Open on a concrete counter-proposal, not a list of questions.** This is the control
mechanism. A question list hands the next move back to the client and reopens everything;
a resolved structure that visibly absorbs their columns is a thing to approve. Keep their
labels wherever the label wasn't the problem — the document should read as their proposal
refined, not replaced.

**Put it first, not last.** This originally said *close* with it, and the DMX draft did;
moving the table to the top was better and it is worth saying why. A reader who has seen the
answer reads the reasoning as support for something they can already picture. A reader who
has not is being walked through six arguments toward a conclusion they cannot see, which is
the shape of being talked into something. Lead with the structure, follow with the verdicts,
then the why.

Leave open only what genuinely needs their answer, and make each one a single decision
with the options named ("one row that lands on the full map, or four pre-filtered rows?").

**Then answer their proposal item by item, in their order, echoing each item above its
response.** One section per thing they proposed — their column, their row, their feature —
titled with *their* label, opening with a quiet block restating what they put in it, and
followed by the response. The DMX draft grouped by our reasoning instead: three columns
adopted together in one section, the renames collected in a footer, the gated-section problem
somewhere else again. Every one of those groupings made sense from our side and none of them
did from theirs, because a reader holding their own document had to work out which part
answered which column.

Three things fall out of getting this right, and they are why it is worth the duplication:

- **It reads without their document open.** Echoing the proposed items means they never
  reconcile two pages.
- **Arguments land where they belong.** A rename gets argued inside the section it renames,
  not gathered into a naming appendix that reads as a list of complaints.
- **The verdict strip becomes an index.** One row per section, same order, same labels —
  clickable straight into the answer. Note the counter-proposal table will *not* be one-to-one
  with it, and that is fine: on DMX the table had five rows to the strip's six, because the
  column being eliminated does not appear in the structure it is being eliminated from.

---

## 5. The document must not narrate itself

Everything cut from the DMX draft in review was the document describing its own existence.
None of it was wrong; all of it delayed the substance, and one piece actively set the wrong
frame.

- **Don't name it after the act of judging them.** The title was "Menu reorganization —
  review"; the review half came off. *Review* says we graded their work, and for a client
  who deliberated that is the frame before they have read a sentence. Name the subject, not
  what we did to it.
- **Cut status meta.** "In response to Table 1" went too. They know what they sent; a
  document that announces its own provenance is throat-clearing. A prepared-for line and a
  date are enough furniture.
- **The lede states the act, not the method.** The draft opened by explaining the evaluation
  criterion — *column by column, against the one test a menu has to pass…* Kaza replaced the
  whole paragraph with **"I counter your menu changes, with menu changes."** One line, and it
  does more: it says what the document is, in the register of someone talking rather than
  reporting. Reach for the sentence that names the act.
- **Sign it as a person.** First person singular throughout. "We think" is a firm issuing a
  position; "I think" is someone accountable for an opinion, which is what a counter-proposal
  actually is — and the plural quietly undercuts the deference line two paragraphs later.
  Keep the plural only for delivery: *the opinion is mine, the build is ours.*
- **A joke that scores a point cannot sit under an opener that credits them.** DMX's own
  document labelled its table "Table 1", so ours captioned its counter-table *"Table 1 — how
  the turntables."* It was asked for, drafted, and then cut — and the reason is worth keeping.
  Once the opener became *I took your changes and adapted them… goal is to make the site more
  awesome*, the gag was working against it: one line says we built on your thinking, the next
  scores off it. The register has to hold all the way down. Warmth and a scoring joke fight,
  and warmth is the one doing the real work.

---

## 6. Tone scales with what they invested

**Ask how much work went into it before choosing a register.** A first sketch takes
directness; a set of decisions they laboured over takes the intent-crediting version of
every counter, or the document lands as a week of their work being marked. The content
does not change — the ordering and the framing do.

**Open with intent and a shared goal, above the verdicts — not with deference.** Something
short has to frame the document before the readout, or "advise against" reads cold as
overruling them. The instinct is to reach for permission-seeking; that is the wrong
instrument, and it was drafted wrong on DMX before Kaza replaced it:

> ❌ *This is my opinion, not a verdict. It's your site — if you read this and still want it
> as you've drawn it, that's what we'll build. I'd just rather say it now than after launch.*
>
> ✅ *I took your changes and adapted them into what I think is better — these are the
> reasons. Goal is to make the site more awesome.*

The second is shorter, warmer and considerably stronger. It says what actually happened
(their work was taken seriously and built on, not overridden), what the document contains
(reasons), and why any of it is worth reading (a better site, which is a goal they already
hold). The first spends three sentences asking permission to have an opinion — which
undercuts every argument beneath it and, read plainly, invites them to ignore the whole
thing.

**Adapted, not corrected, is the frame.** "I took your changes and adapted them" is true of
a good review and it is the sentence that lets the pushback land, because it puts us
downstream of their thinking rather than opposite it.

Defer on authority where it genuinely applies, never on substance, and never as an opening
posture.

Watch the two-word verdicts hardest, for two different reasons.

**They out-weigh the paragraph they summarise.** "Recommend against" reads as a ruling,
"We'd advise against" as counsel. Same position, and the second one survives contact with
someone who is proud of the column.

**And they go stale silently.** A verdict is written early, against the first answer, in a
document that then gets argued for hours — so it is the element most likely to be wrong at
the end and the least likely to be re-read, because it looks finished. On DMX a chip read
*Filters, not pages* long after the recommendation had become three addressed pages; it was
accurate against the first answer and false against the shipped one, and the client caught
it, not us. **Re-read every verdict against the section it now heads before sending**, and
treat any that still matches its first draft as unchecked rather than settled.

Never characterise the proposal as a whole. No "this is confusing", no "several of these
are worse". Every criticism attaches to one named item and carries its alternative.

---

## 7. What this document is not

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

## 8. Output

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

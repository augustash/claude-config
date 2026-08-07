---
name: A defect nobody can see still gets fixed — we own the whole stack
description: "Before dismissing a sub-pixel or off-screen flaw as too small to matter, or reporting it as a known-but-acceptable quirk. On builds we author end to end there is no inherited-mess excuse, and 'nobody will notice' is a bet that nobody looks closely."
type: feedback
---

# A defect nobody can see still gets fixed

**Kaza, md 2026-08-07:** *"Especially on this site, it's ours. We're not dealing with someone
else's mess, we're dealing with our mess. So we completely control it. Just because no one sees
it, doesn't mean it's ok for it to be a disaster. That's the difference between us and our
competitors — we make top quality clean gorgeous sites in and out. I'm really always trying to
make the best site I can make from every perspective."*

**Why:** on a build we authored end to end, every flaw is one we put there and one we can
remove. "Nobody will notice" is not a judgement about severity — it is a bet that nobody looks
closely, and it loses the moment someone does. It also compounds: the tolerance, not the
pixel, is what accumulates into a codebase that is merely fine.

**And a display bug is never only a display bug — it is the one part of the build a stranger
can audit.** Kaza, md 2026-08-07: *"If I look at a site and see display issues, it makes me
instantly suspect that the level of detail is questionable, and suspect the backend is going
to be really scary — because that is the hard part."* The front end is the **easier** half and
the only half on show, so sloppiness there is read, correctly, as evidence about the half
nobody can inspect. That inference runs on our work too: a visitor, a client, or the next
developer has no other signal to go on.

The case that produced it is the shape to recognise. A 1.5rem glyph in a small-caps table
header inflated the header row by ~6.7px, which rounded a fractional row height to a whole one
and showed as a **1px seam** under one column. Invisible until Kaza put a red background behind
it to check. The same defect had been sitting in a second table since that control shipped,
where roomier headers hid it entirely — so the version nobody could see was the one that would
have survived the fix.

**How to apply:**

- **Don't file "too small to matter" as a finding and move on.** If it is genuinely ours and
  genuinely wrong, fix it. Report the ones you are *not* fixing and why, rather than using
  invisibility as the reason.
- **When a flaw shows in one place, look for where it is hiding.** The instance you noticed is
  rarely the only one; it is the one whose spacing happened to expose it. Fixing only the
  visible instance leaves the real bug live and armed.
- **Reach for a measurement when the eye is unsure.** Toggle the suspect off and re-measure —
  row height with and without the element — rather than arguing about whether a pixel is
  really there. That is what turned "about 1px high" into "+6.61px on one table, +6.73px on
  the other, now 0".
- **This is not licence to gold-plate.** It applies to defects — things that are wrong — not
  to polish nobody asked for. The distinction is whether you would be embarrassed to have it
  pointed out.

Related: [[style-rules-cover-ground]] is the other half — this one says *fix it*, that one says
*fix it at the widest level that is true*. The 1px seam needed both: found in one component,
real in two, fixed once for all table headers.

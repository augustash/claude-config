---
name: quote-the-tooling
description: Price a fix on the experience and tooling that make it quick, not on the minutes it takes us now.
metadata:
  type: feedback
---

# Quote the tooling, not the minutes

When a fix is quick because of something we built, the quote carries a share of building
it. Our modules and tooling (drupal_cache_protection, the log-audit and accessibility
harnesses, the exo fixes that reach every site) are plug-and-play because we did the work to
work out what sites need: the scanning that finds the problem, the module that's ready to
cover it. That cost is spread across every client who uses the tech, and each quote takes
its share.

**Why:** Kaza, metro 2026-10-23. A POM+ access-log pass found MAC's campaign tracking code
(`apcid`) busting the page cache on every send. The fix is one entry in
drupal_cache_protection's strip list, so an agent quoted 0.5 h. Kaza: *"Would anyone else
have thought to have scanned their access logs and find this cache bust, and have a module
built and ready to cover it? Sure, but it's only going to be people with a fair amount of
experience, that's us. So I'd bill 2 hrs."* Half an hour was right for the keystrokes and
wrong as a price.

**How to apply:** when an estimate is small *because* our tooling already covers the case,
price the finding and the readiness, not the edit: about the time it would take a capable
team without our tooling to find and fix it. Raw hours still apply to genuinely one-off work
that builds on nothing of ours. Agents' estimates are keystroke estimates; adjust them before
they reach a Work row, and expect the dev to adjust further. Work rows still show the math
at the shared rate ([hourly-rate.json](hourly-rate.json)); this changes the hours, not the
rate.

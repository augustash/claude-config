---
name: Trust contrib tests; only cover code we own
description: Don't write tests that re-verify contrib (Drupal core/contrib, composer libraries) behavior; cover only the seam between our code and theirs
type: feedback
---

When deciding test scope on a change that touches contrib code, draw the boundary at our seam. Verify that our hook fires with the right inputs, that our config sets the values we promised, that our service is wired into the right pipeline — then stop. Don't write a test whose pass/fail depends on contrib code doing its own documented job correctly.

**Why:** taking responsibility for contrib's behavior is silly — their code can't reach live without passing all of *their* own tests, so duplicating their coverage in our suite only adds noise we have to maintain when their API shifts. Our test budget is better spent on the seam we own, which is the part most likely to silently rot when we refactor.

**How to apply:**

- **Do test:** that our hook/alter sets the value we promised, that our event subscriber listens on the right event, that our config exports the elements we expect, that our token resolves the data we claim it resolves.
- **Don't test:** that webform actually puts that value into the rendered email, that Drupal core's render pipeline calls our `#process` callback, that Symfony's container resolves a service we registered — these are contrib's contract and they have their own tests.
- **Quick gut check before writing an assertion:** "Is this describing *our* behavior, or *theirs*?" If theirs, drop it.
- **Pairs with [[test-reminders]]:** that memory says surface coverage gaps for new behavior we add — this one bounds what counts as *our* behavior in the first place.

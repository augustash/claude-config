---
name: Trust contrib tests; only cover code we own
description: Don't write tests that re-verify contrib (Drupal core/contrib, composer libraries) or third-party-API behavior; cover only the seam between our code and theirs
type: feedback
---

When deciding test scope on a change that touches contrib code, draw the boundary at our seam. Verify that our hook fires with the right inputs, that our config sets the values we promised, that our service is wired into the right pipeline — then stop. Don't write a test whose pass/fail depends on contrib code doing its own documented job correctly.

**External service APIs are the sharpest case of "not ours."** Payment gateways (Authorize.net, Affirm, PayPal, Amazon Pay), Klaviyo, ShareASale — their behavior lives behind a network boundary and an SDK we don't own, so a test that exercises it is both out of scope *and* flaky/non-deterministic. Never hit a live API from the suite. When a flow has to pass *through* an external integration to reach the part we own, substitute the on-site/dummy equivalent so the test stays deterministic and SDK-free — e.g. drive end-to-end checkout with the built-in `manual` payment gateway (check/money order) instead of a real card gateway. The seam we test is "does our flow reach completion and place the order"; whether the gateway's API captures funds is the vendor's contract.

**Why:** taking responsibility for contrib's behavior is silly — their code can't reach live without passing all of *their* own tests, so duplicating their coverage in our suite only adds noise we have to maintain when their API shifts. Our test budget is better spent on the seam we own, which is the part most likely to silently rot when we refactor.

**How to apply:**

- **Do test:** that our hook/alter sets the value we promised, that our event subscriber listens on the right event, that our config exports the elements we expect, that our token resolves the data we claim it resolves.
- **Don't test:** that webform actually puts that value into the rendered email, that Drupal core's render pipeline calls our `#process` callback, that Symfony's container resolves a service we registered — these are contrib's contract and they have their own tests.
- **Quick gut check before writing an assertion:** "Is this describing *our* behavior, or *theirs*?" If theirs, drop it.
- **Pairs with [[test-reminders]]:** that memory says surface coverage gaps for new behavior we add — this one bounds what counts as *our* behavior in the first place.

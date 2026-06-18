---
name: Playwright UI test writing
description: Conventions for tests/ui Playwright suites — run resource-heavy tests serially, wait on conditions not time, warm caches before timing-sensitive tests.
type: feedback
---

Lessons for writing Playwright tests against our sites:

- **Run resource-heavy tests serially.** Tests that drive lots of backend work — paging a large listing through many renders, anything that hits PHP-FPM + Solr + first-hit image-derivative generation repeatedly — *starve each other* when run in parallel against a constrained backend. Symptom: timeout flakes / "stuck" element counts under `fullyParallel: true`, but green when run one at a time (`--workers=1`). Scope it with `test.describe.configure({ mode: 'serial' })` on the heavy describe; don't disable parallelism globally. This is a local/test resource artifact, **not** a production concern (a cache warmer + per-URL caching keep prod requests warm).

- **Wait on the observable, never a fixed delay.** (See [[no-time-based-test-waits]].) For infinite scroll: scroll, then `await locator.nth(n).waitFor()` for the next element rather than `waitForTimeout`. Keep the timeout generous so a cold render doesn't trip it, while warm runs stay fast.

- **Cold-cache first-hit is the sneaky flake.** The very first request after a cache clear pays the cold cost (full render + derivative generation), and the IntersectionObserver may not fire promptly while the page is still settling. A larger timeout helps but isn't bulletproof. The reliable fix: **warm the URLs under test in a `beforeAll`** (fetch the landing page + the AJAX/load-more pages) so tests run against the warm steady state — which is also what real users get.

- **baseURL via env.** Suites default `baseURL` to the live site and accept a `BASE_URL` override for local (e.g. the ddev URL). A feature not yet deployed must be tested against local, not live. WebKit projects need `npx playwright install webkit` before they'll run.

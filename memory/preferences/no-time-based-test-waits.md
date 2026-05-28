---
name: Wait on conditions in tests, never on fixed time
description: Don't gate test steps on arbitrary delays (waitForTimeout/sleep/pause). Wait on the real observable — element state, a network response, a count change. Time-based waits are both flaky and slow.
type: feedback
---

In tests, never gate a step on a **fixed duration** (`waitForTimeout`, `sleep`, `pause`, arbitrary `await delay`). Wait on the **actual condition** you care about: an element attaching/becoming visible, a specific network response, a count or text change.

**Why:** a time wait is wrong in both directions. Too short and it fails when the system is momentarily slow; too long and every run wastes that time. Concrete burn: a Playwright infinite-scroll test used `waitForTimeout(900)` between scrolls, but the load-more request took ~1.5s to render server-side — so the test bailed and *aborted the in-flight request* (`status: -1`), reporting a false failure. Switching to "wait until the next card attaches (up to 6s)" fixed it and is faster on fast runs. As the dev put it: *time is generally a terrible condition*.

**How to apply:**

- **Playwright:** `locator.waitFor({ state })`, `expect.poll(...)`, `page.waitForResponse(...)`, `page.waitForFunction(...)` — not `waitForTimeout`.
- **Nightwatch:** `waitForElementVisible` / `waitUntil`, not `pause()`.
- General rule: wait for the *observable effect* of the thing, with a generous timeout, rather than guessing how long it takes.
- The rare exception is debounce/animation settling where there's genuinely no observable signal — keep those waits tiny and comment why.

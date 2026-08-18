---
name: Drupal ajax buttons fire on mousedown
description: "A scripted `.click()` on a Drupal ajax button does nothing at all — core binds the handler to mousedown. The request never goes out, the page sits there looking correct, and the reproduction reads as \"cannot reproduce\" while the developer hits the bug every single time by hand."
metadata:
  type: reference
---

# Drupal ajax buttons fire on mousedown

Core binds ajax form submits and ajax buttons to **`mousedown`**, not `click`. So driving one
from a script:

```js
saveButton.click();          // nothing happens. No request. No error.
```

Dispatch the real sequence instead:

```js
['mousedown', 'mouseup', 'click'].forEach(type =>
  button.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true })));
```

## Why this costs hours rather than minutes

The failure is **silent and looks like success**. The click "works", no exception is thrown,
and the page is in a perfectly valid state — it just never submitted. Every measurement taken
afterwards is of a page where nothing happened, so the trace comes back clean and the honest
conclusion is *"I can't reproduce it."*

On ar-md (2026-08-17) five consecutive scripted reproductions of an Alchemist save came back
stable — no scroll, no reload, no error — while the developer reproduced it on every attempt
by hand. The tell was his: *"you're not doing it the way I was."* Adding `mousedown` reproduced
it immediately, and the trace named the cause in one run.

**So: when a scripted reproduction is clean and a human's is not, suspect the input, not the
code.** Confirm the action actually happened (did the modal close? did a request go out?)
before believing a negative result. A `has-neo-modal` still on `<body>`, or a form element
still in the DOM, means the submit never fired.

Same trap in reverse: alchemist's own JS already knew this — `component-parent.ts` dispatches
`mousedown` to trigger the managed-file Remove button — so the knowledge was in the codebase
and still cost a session, because nothing points you at it when your problem looks like
"the bug doesn't reproduce".

Related: [[playwright-testing]] for UI test writing, [[nightwatch-testing]] for the Selenium
harness.

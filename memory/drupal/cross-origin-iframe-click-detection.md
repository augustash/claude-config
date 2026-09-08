# Detecting a click into a cross-origin iframe

You cannot see events inside a third-party embed, and you cannot fake one going the other way.
A `MouseEvent` dispatched in the parent — at any coordinate — fires on the `<iframe>` element in
*our* document and is never hit-tested into the child. `document.elementFromPoint()` stops at
the same boundary. This is what same-origin policy is for: if a parent could click into a
cross-origin frame by coordinate, clickjacking would be a two-line script.

Playwright and Puppeteer *can* do it, which makes the restriction look like something we're
missing. They drive `Input.dispatchMouseEvent` over the DevTools Protocol, which injects at the
browser's input layer, above the document tree — a capability the browser holds and does not
delegate to page script. `isTrusted: true` can't be forged. If a technique only works in a test
harness, that's usually why.

## What does cross the boundary

A click anywhere inside the frame makes the iframe element the parent document's
`activeElement`. That's the whole signal — you learn the frame was clicked, never *what* was
clicked.

**Poll for it on the rising edge. Do not use `window.blur`.**

```js
var hadFocus = false;

window.setInterval(function () {
  var focused = document.activeElement === iframe;
  var entered = focused && !hadFocus;

  hadFocus = focused;

  if (entered && !document.hidden) {
    // The frame was just clicked into.
  }
}, 200);
```

`window.blur` + `document.activeElement` is the technique every answer online reaches for, and
it fails intermittently in a way that's miserable to diagnose: **blur only fires if the page
held focus in the first place.** Click straight into the embed after a reload — where focus is
still on the browser chrome, not the document — and focus moves into the frame without the
parent ever blurring. No event. It works on first load, breaks after a refresh, and looks like
a caching problem. `activeElement` is true wherever focus came from.

The rising edge matters as much as the polling. Level-triggered, every tick re-fires while the
visitor works inside the frame; edge-triggered, a control of ours that takes focus back (a
button in the parent) naturally re-arms the next entry, so you don't need a "dismissed" flag to
stop the two fighting over the same panel.

Keyboard tabbing into the frame is also a focus entry, so it triggers too — usually what you
want, but say so in a comment before someone files it as a bug.

Worked out on wps, driving a CareerArc map embed whose own job list had to open when a pin was
clicked — see [[third-party-iframe-touch-scroll-trap]] for the other half of taming that embed.

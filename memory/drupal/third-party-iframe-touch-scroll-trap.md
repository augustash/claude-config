---
name: A third-party map iframe eats one-finger page scroll on touch
description: embedding a vendor map or similar interactive iframe; on a phone the page can't be scrolled past it, and exo has nothing to reuse
type: project
---

An interactive third-party iframe — a vendor job map, a store locator, anything Google
Maps-backed — captures one-finger drags on touch. The visitor swipes to scroll past it, the
map pans instead, and the page is stuck. The taller the frame, the worse: a 60vh embed near
the top of a page can be genuinely impassable on a phone.

## Measure desktop before building anything

Desktop is often already fine, because Google Maps' `gestureHandling: 'cooperative'` makes a
plain wheel scroll the page and reserves ctrl+wheel for zoom. Vendors usually set it. Don't
assume either way — put the pointer over the frame, wheel, and read `window.scrollY` before
and after. If it moved, the fix is touch-only and the CSS gate below is all the scoping you
need.

## exo has nothing for this — don't re-sweep it

`exo_oembed` ships an `exo_oembed_click` formatter that is the closest thing in spirit (it
swaps a link for an iframe on click), but it is a **field formatter** bound to link/string
fields through oEmbed resolution, so it can't touch an iframe built in a preprocess plugin or
a template — and it still calls jQuery-era `.once()`, so it is pre-D10 dead code. `exo_video`,
`exo_modal` and `exo_entity_browser` iframe code is all modal/browser plumbing. Nothing in exo
handles gesture capture.

**What exo does give you is the device hook:** exo core puts `has-touch` / `no-touch` on
`<body>` and exposes `Drupal.Exo.isTouch()`. Gate the fix on `.has-touch` in CSS and write no
detection of your own.

## The fix: a shade you tap through

A full-cover **`<button>`** over the iframe, hidden by default and shown only under
`.has-touch` on a wrapper without an active class. Tapping it sets the active class; an
`IntersectionObserver` clears that class when the wrapper leaves the viewport, so the map
re-arms and can't trap a later swipe on the way back up.

Three details that matter:

- **`pointer-events: none` on the iframe cannot work.** It would block the activating tap too,
  so you need a sibling element to catch it. The shade *is* the mechanism, not a decoration.
- **A `<button>`, not a div.** Keyboard- and AT-correct for free, and `display: none` on
  pointer devices drops it out of the accessibility tree entirely rather than leaving a
  mystery control in the tab order.
- **Default it to hidden**, revealed only by the `has-touch` class. If exo's JS never runs the
  visitor gets a fully interactive map, which is the right failure.

A transparent shade does not block page scrolling — a swipe over it scrolls the page normally,
which is the whole point. Give it a visible label ("Tap to interact with the map") or the
first tap reads as a dead map.

## You cannot script the embed's own UI

Cross-origin means `iframe.contentDocument` is null, so there is no node to dispatch a
synthetic click at — the blocker is *addressing*, not listening. Real user input works only
because the browser hit-tests and routes it itself. Before telling anyone it's impossible,
grep the vendor bundle for a `postMessage` API; usually every `message` listener in there
turns out to be library plumbing (Sentry, Turbo, the React scheduler, Lexical).

Related: [[sidescroll-dead-zones]] covers the horizontal mirror of this — and Kaza's rule that
a plain vertical wheel must never be hijacked, which is exactly why the shade waits for a
deliberate tap instead of trying to be clever about gestures.

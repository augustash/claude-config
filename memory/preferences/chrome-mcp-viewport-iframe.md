---
name: resize_window does not resize the page's viewport — frame it same-origin instead
description: "The Chrome MCP tab renders at a fixed ~1920 viewport whatever the window is set to, so a `resize_window` then screenshot returns the DESKTOP layout labelled as mobile. A same-origin iframe sized 390x844 gives a genuine narrow viewport — real media queries, real vw units — and stays scriptable because it is same-origin."
type: feedback
---

# A mobile screenshot from `resize_window` is the desktop layout

`mcp__claude-in-chrome__resize_window` reports success and changes the OS window, but the page
keeps reporting `innerWidth: 1920`. Media queries never fire, so the screenshot is the desktop
layout at a smaller window size. Nothing errors — which is the problem, because the picture
looks like evidence.

Always assert the viewport before trusting a responsive screenshot:

```js
JSON.stringify({iw: innerWidth, ih: innerHeight})   // 1920 means resize did nothing
```

## Frame it instead

An iframe gets its own layout viewport, so a 390x844 iframe is a **real** 390px viewport —
media queries, `vw`, breakpoint classes, all correct. Most of our sites send
`X-Frame-Options: SAMEORIGIN`, so host the frame on a page of the *same site* and the browser
allows it:

```js
const f = document.createElement('iframe');
f.style.cssText = 'width:390px;height:844px;border:0';
document.body.appendChild(f);
f.src = '/articles/burger-board';        // same origin as the host page
await new Promise(r => f.addEventListener('load', r, {once: true}));
f.contentWindow.innerWidth;              // 386 — genuinely narrow
```

Same-origin also means it stays **scriptable**: `f.contentWindow.Drupal` is reachable, so a
modal or menu inside the frame can be opened and measured, not just looked at. That is the
whole reason to prefer this over faking it with CSS on `.exo-modals` or stubbing
`Drupal.Exo.$window.width()` — those change the numbers the JS reads without changing the
layout the browser performs, so they prove less than they appear to.

## Two other walls in the same tool

- **HTTP basic auth is a hard stop.** Pantheon's env lock 401s, and Chrome rejects
  `https://user:pass@host/` from `location.href` as well as from the navigate tool — the tab
  lands on an error page. There is no in-browser way through: either work against an unlocked
  environment, or `terminus lock:disable`, shoot, and `lock:enable <site.env> <user> <pass>`
  straight after. Note the positional arguments — `--username=` / `--password=` is rejected and
  leaves the environment **open**, so always re-read `lock:info` to confirm it locked.
- **`zoom` regions are screenshot-frame coordinates, not page coordinates**, and the two differ
  whenever the capture is scaled. Take a screenshot first and measure off that frame.

**How to apply:** whenever a screenshot is meant to prove responsive behaviour, print
`innerWidth` in the same call that takes it. On kow (2026-09-03) the first three "mobile"
captures of a broken video modal were 1920-wide renders with the modal box faked by CSS; the
iframe method produced the real 386px layout and the numbers then matched the client's own
phone screenshot to within a pixel. Related: [[mobile-breakpoint-check]].

---
name: LiveChat widget container click-trap (third-party height override)
description: A third-party stylesheet rule force-extends #chat-widget-container's height, turning the empty area above the bubble into an invisible click-blocker
type: project
---

LiveChat's `#chat-widget-container` is naturally small (~84×84 — sized to its bubble button via inline `style` attributes). Other scripts on the page can override that with stylesheet rules like:

```css
body.cc-ftr-menu #chat-widget-container {
  height: 94% !important;
  max-height: 94% !important;
  bottom: 65px !important;
}
```

(Observed from ConvertCart's footer-nav integration on a Drupal Commerce site — body class `cc-ftr-menu` is a giveaway. Other widget integrations may inject similar rules.)

When that rule fires, the wrapper stretches to nearly the full viewport height while only the small bubble at the bottom is visible. The empty area above the bubble retains `pointer-events: auto` and intercepts clicks on whatever sits behind it — most commonly a top-corner mobile hamburger or a side-overlay back arrow. The visible chat widget itself looks fine, so the bug presents as "menu icon doesn't respond to clicks" with no obvious cause.

**Why this is hard to diagnose:**

- The wrapper is transparent; only DevTools "Inspect element" on the affected control reveals it.
- LiveChat is often gated by env (e.g., `getenv('IS_DDEV_PROJECT')` skip in `livechat.module`) so the bug doesn't reproduce on local dev.
- Browsers with enhanced tracking protection (incognito Chrome/Edge, Safari ITP) block the chat-widget script entirely — so the bug only shows in normal-mode Chromium browsers, masquerading as a CDN-cache or sessionStorage-popup issue.

**Diagnostic technique (Playwright or DevTools console):**

```js
const el = document.querySelector('SELECTOR_FOR_BROKEN_BUTTON');
const r = el.getBoundingClientRect();
document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
```

If the answer is anything other than the button or its descendants, walk up to find the obstructor. An iframe with id like `chat-widget-minimized` or a wrapper like `#chat-widget-container` is the smoking gun.

**Fix priority order:**

1. **Find the script writing the override.** It's often configurable (e.g., a "chat widget offset" setting in ConvertCart admin) and removing it at the source is cleanest. Grep the codebase for `cc-ftr-menu`, `chat-widget-container`, `94%`, etc.
2. **CSS override with higher specificity** if the rule lives in an injected `<style>` block (cascade-comparable). Beats the offending rule with `html body.cc-ftr-menu #chat-widget-container { height: auto !important; max-height: none !important; }` — the extra `html` element bumps specificity above theirs.
3. **JS MutationObserver** as last resort if the styles are truly on the element's `style` attribute with `!important`. Use `el.style.setProperty('height', 'auto', 'important')` (which can override inline `!important`) and re-apply on style mutation.

Keep `bottom`-style positioning rules from the offending stylesheet if they intentionally make room for a footer nav. Only override `height` / `max-height`.

**How to apply:** when "menu icon doesn't respond to clicks" presents on a Drupal site with the LiveChat module + a chat widget integration, check `document.elementFromPoint` over the broken control before assuming cache, popups, or JS bugs. If a chat-widget element is the hit, look for stylesheet rules forcing the container's height beyond its natural bubble size — the override pattern above resolves it. The same shape of bug can happen with Intercom, Drift, HubSpot, or any cross-origin-iframe widget whose container can be force-expanded by other scripts on the page.

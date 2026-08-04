---
name: Driving LiveChat from your own trigger instead of its floating bubble
description: call('hide') tears the widget out with no close animation, get('state') throws before load, and any bottom offset added to clear the bubble past a sticky bar clips the opened window's title bar
type: reference
---

Clients ask for chat to live in a menu rather than as a floating bubble. LiveChat
supports it, but three things bite in order.

## Close with `minimize`, suppress the bubble in CSS

The obvious build is `call('hide')` on close — and it's wrong. `hide` removes the
widget outright, so there is **nothing left to animate**: the window vanishes
instead of collapsing. `minimize` is the true reverse of `maximize` and plays
LiveChat's own animation, but it lands on the bubble.

So minimize to close, and keep the bubble out of sight in CSS:

```css
#chat-widget-minimized {
  display: none !important;
}
```

Confirm the id rather than assuming it — it's a constant in `tracking.js`
(`dt="chat-widget-minimized"`, alongside `chat-widget` and
`chat-widget-lightbox`). Use `display`: LiveChat drives those frames with inline
`opacity` / `visibility` / `z-index`, so a different property doesn't get
overwritten.

This also avoids a timer. Hiding *after* the animation means listening for
`transitionend` on the container with a fallback timeout, and a bubble that
flashes for a frame at the end. Nothing left to hide, nothing to time.

## Track visibility, don't ask for it

`get('state')` throws until the widget finishes loading — the embed snippet says
so itself: `"You can't use getters before load."` A launcher that toggles has to
know whether the window is open, so hold the value from the event instead:

```js
widget.on('visibility_changed', function (data) {
  visibility = data.visibility;
});
```

`availability_changed` is worth wiring too. The bubble signalled "no agents" on
its own; a menu item can't, so expose it as a class for the theme.

If the launcher sits inside an overlay — an exo_modal, an off-canvas menu — close
that first (`Drupal.ExoModal.closeAll()`), or the chat window opens behind it.

## The offset that cleared the bubble clips the window

The trap worth remembering. Themes routinely lift `#chat-widget-container` off
the bottom so the **bubble** clears a mobile sticky bar:

```scss
#chat-widget-container {
  bottom: rem-calc(74) !important;
}
```

Harmless while only a ~84px bubble is visible. Move to a custom launcher and the
window opens *in that same container* — still bottom-anchored at 74px, still
sized against the full viewport, so its top 74px, the title bar, is pushed off
screen. It reads as "the chat window opens too big", not as a positioning bug.

Give the offset back out of the height:

```css
@media screen and (max-width: 39.9375em) {
  html body #chat-widget-container { max-height: calc(100dvh - 74px) !important; }
  html body #chat-widget-container iframe { max-height: 100% !important; }
}
```

The iframe rule is needed because LiveChat sets that height inline. Watch
specificity: a `html body.<class> #chat-widget-container` rule from
[[livechat-click-trap]] outranks any plain `#chat-widget-container` a theme can
write, so the cap belongs in the same file as that override, later in source
order — not in the theme, where it silently loses.

This qualifies that memory's closing advice to keep `bottom` rules and override
only `height`/`max-height`. That holds while the bubble is the only thing on
screen; once your own trigger opens the window directly, the `bottom` rule needs
a matching height cap or it clips.

## What you don't control

The window is a cross-origin iframe from `secure.livechatinc.com`. Yours: whether
the script loads and where, the `window.__lc` init params (license, `group`,
`params`, visitor prefill), the whole JS API, and CSS on the outer container.
Not yours: anything inside — colours, greetings, pre-chat fields, and the
minimize/close glyph in the header.

When a client asks to change that glyph, the answer is the LiveChat dashboard,
not code. Overlaying your own control positioned over their header "works" until
they reshuffle it, then leaves a stray button floating over the wrong spot with
no error and nothing in a test suite to catch it. Not worth it for one glyph.

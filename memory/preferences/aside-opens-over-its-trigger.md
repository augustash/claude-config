---
name: An aside opens from the side its trigger is on
description: Slide an off-canvas panel in from the edge nearest the button that opened it, so it covers that button rather than appearing across the screen.
metadata:
  type: feedback
---

# An aside opens from the side its trigger is on

An off-canvas panel (an exo `aside_left` / `aside_right` modal, a drawer, a
filter sheet) slides in **from the edge nearest the control that opened it**, so
it lands over that control. A Filter button at the left of a listing opens a
left aside; a cart icon at the top right opens a right one.

Kaza, moving sisal's product filter aside from `aside_right` to `aside_left`
(2026-10-08):

> I prefer to have my aside open overtop of the clicked button, its more
> efficient and directs attention better. Better ux.

**Why:** the visitor's eyes and pointer are on the button they just pressed.
A panel that arrives on top of it keeps both where they already are; one that
opens on the far side makes them hunt across the screen, and on a wide display
a right-hand panel opened from a left-hand button can sit outside where they're
looking entirely. Closing it also returns them to the spot they left.

**How to apply:** when wiring any aside, pick its side from where its trigger
sits, not from habit or a module's demo default (exo's demos lean on
`aside_right`). If one panel has triggers on both sides, side with the primary
one. Applies to [[follow-site-conventions]] only as far as the site has no
established pattern of its own; a site that already opens everything from one
side is a conversation, not a silent override.

# Sign generated docs with the studio mark

Every document we generate for a client or the team — report, reference page, plan,
findings — ends with the studio's mark, **centered at the very bottom**, with generous
space above and below. It is a sign-off, not a masthead: small, alone, after the footer
text.

- **August Ash work** → the A mark:
  [templates/brand/august-ash-mark.svg](../../templates/brand/august-ash-mark.svg)
  (two-tone blue, from the augustash.com `logo_mark` block). Inline the SVG as-is.
- **Ashen Rayne work** → the shield:
  [templates/brand/ashen-rayne-shield.svg](../../templates/brand/ashen-rayne-shield.svg),
  the shield alone from the new Ashen Rayne logo (Kaza, md 2026-11-21: "use just the shield").
  A vector, so it stays sharp at any size. Inline the SVG as-is; its IDs carry an `ar-`
  prefix so it can't collide with a page's own. The wordmark is left out on purpose: it is
  set in a light cream meant for a dark ground and would vanish on a white doc.

  This replaced the earlier mark on record, a hover credit (colour shield sliding out a
  wordmark, from the dmx-power.com footer sprite) and its 35×44 PNG shield. Docs built
  before 2026-11-21 still carry that one inline.

Which studio a project belongs to is a per-project fact. When it isn't recorded, ask.

**Why:** Kaza's rule (loft, 2026-09-14). A client doc gets forwarded away from the email
it came in, and the mark is what keeps who made it attached to it. It also keeps our docs
consistent without adding a masthead that competes with the content.

**How to apply:**

- Put it after the footer: `display: flex; justify-content: center; padding-block: 64px`.
  The mark pads **both** sides itself. Leaving the bottom to "the page's own padding" once
  left the shield flush against the bottom edge, because the credit sat after the padded
  content column, outside it (Kaza, DMX catalog questions, 2026-09-30). About **56px wide** for
  the A mark and **44px tall** for the shield.
- Inline it either way. [[deliverables-as-html-files]] requires a doc that opens offline,
  so never link the file.
- Both marks are full colour and read on light and dark grounds. Don't recolour them to
  the client's palette.

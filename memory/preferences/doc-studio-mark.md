# Sign generated docs with the studio mark

Every document we generate for a client or the team — report, reference page, plan,
findings — ends with the studio's mark, **centered at the very bottom**, with generous
space above and below. It is a sign-off, not a masthead: small, alone, after the footer
text.

- **August Ash work** → the A mark:
  [templates/brand/august-ash-mark.svg](../../templates/brand/august-ash-mark.svg)
  (two-tone blue, from the augustash.com `logo_mark` block). Inline the SVG as-is.
- **Ashen Rayne work** → the shield:
  [templates/brand/ashen-rayne-shield.png](../../templates/brand/ashen-rayne-shield.png),
  the colour shield cropped from the DMX Power footer-credit sprite. Inline it as a
  `data:image/png;base64` URI.

Which studio a project belongs to is a per-project fact. When it isn't recorded, ask.

**Why:** Kaza's rule (loft, 2026-09-14). A client doc gets forwarded away from the email
it came in, and the mark is what keeps who made it attached to it. It also keeps our docs
consistent without adding a masthead that competes with the content.

**How to apply:**

- Put it after the footer: `display: flex; justify-content: center; padding-block: 64px 0`,
  with the page's own bottom padding supplying the space below. About **56px wide** for
  the A mark and **44px tall** for the shield.
- Inline it either way. [[deliverables-as-html-files]] requires a doc that opens offline,
  so never link the file.
- Both marks are full colour and read on light and dark grounds. Don't recolour them to
  the client's palette.
- ⚠ The shield source is only **35×44px**, the best available (ashenrayne.com serves the
  same 218px logo). Don't show it above 44px tall or it goes soft on retina. Replace the
  file here if a vector turns up.

---
name: site-thumbnails
description: Wanting a periodic picture of each site — Pantheon has no such API, and the two things that ruin the result are consent banners and clicking to dismiss them
type: project
---

**Pantheon exposes no screenshot, thumbnail or preview of a site.** Verified against both
`terminus site:info` and the raw API site record: there is no such field, on any plan. The
dashboard's visual is generated client-side and is not retrievable.

So a thumbnail has to be rendered. Playwright on a machine that already has terminus is the
cheap answer — free, and no third party is handed a list of which client sites the agency
runs, one URL at a time, every week. A Pantheon container cannot do it: no Node, no browser,
no way to install one.

## Hide consent banners; never click them

Nearly every site has a cookie notice, and it lands across the middle of the viewport — so
without intervention a third of every thumbnail is a consent dialog and the sites become
*harder* to tell apart, which defeats the point.

Suppress with injected CSS, **not** by clicking "Accept". Clicking records a consent decision
on a client's live site, on our behalf, weekly, forever. That is not ours to make. Hiding
changes nothing server-side.

```js
await page.addStyleTag({ content: `
  #sliding-popup, .eu-cookie-compliance-banner,      /* Drupal EU Cookie Compliance */
  #klaro, .klaro .cookie-notice,
  #onetrust-banner-sdk, #CybotCookiebotDialog,
  #cookie-law-info-bar, .cli-modal,                  /* WordPress */
  .cc-window, .osano-cm-window, #usercentrics-root
  { display: none !important; }
` });
```

Inject **after** the settle, not at load — most banners are script-injected, so a style tag
added at `domcontentloaded` has nothing to match yet.

## The rest of what matters

- **`waitUntil: 'domcontentloaded'` plus a fixed settle**, never `networkidle` — it never
  settles on anything with a chat widget or an analytics beacon, which is most of a fleet.
- **Above the fold only.** A full-page capture is an illegible ribbon at thumbnail size, and
  it waits on lazy images nobody will see.
- **JPEG, not PNG.** A screenshot of a real page is a photograph; PNG stores it losslessly at
  roughly six times the size for no visible gain.
- **Verify magic bytes before storing.** A failed render arrives as an HTML error page, and
  writing that to `.png` yields a broken thumbnail that reads as "this site is broken" — a
  very different fact from "we could not photograph it".
- **Record where the render landed.** The platform domain
  (`https://live-<site>.pantheonsite.io/`) redirects to the real primary domain, so following
  it captures each site's actual domain for free — otherwise one API call per site.

Related: [[playwright-testing]] for the UI-test use of the same tool.

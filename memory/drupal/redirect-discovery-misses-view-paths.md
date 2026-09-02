---
name: A redirect pass built on aliases and hrefs cannot see view paths
description: legacy URLs served by a Views page display have no url_alias row, so alias- and href-driven redirect discovery is structurally blind to them — and they are disproportionately the high-traffic browse URLs
type: reference
---

A redirect batch for a legacy migration is usually built two ways: resolve every
`href` found in migrated content, and walk the old `url_alias` table. Both passes
share a blind spot. **A page served by a Views page display has no `url_alias`
row** — the path lives in the view's own configuration — so it is invisible to
the alias pass, and if nothing in the body content linked to it, invisible to the
href pass too.

The result is not a URL that was overlooked. It is a whole *class* of URL that
nothing was looking for.

**And it is the worst class to miss.** View paths are the browse and listing
pages — locators, directories, filtered catalogs, document indexes — exactly the
URLs that accumulate inbound links and nav prominence over a site's life. On DMX
Power, `/distributor-locator` was **990 views/30d, the #4 URL on the entire
site**, 404ing with no redirect row and no entry in the batch. It surfaced during
an unrelated menu review, not from any redirect pass.

**How to check.** The redirect table and the batch script are both the wrong
place to look, because neither knows what it is missing. Take the *log's* top
URLs — a traffic ranking, not a content inventory — and resolve each against the
`redirect` table:

```
ddev drush sqlq "SELECT COUNT(*) FROM redirect WHERE redirect_source__path='<path>';"
```

Anything returning `0` with real traffic behind it is a gap. This is the only
pass that starts from what people actually requested rather than from what the
old CMS happened to record as a node.

⚠ **Point the redirect at the destination route path, and know that this is a
dependency rather than a safeguard.** A route path does **not** follow a later
rename the way an alias does — if the destination route moves, the redirect must
be retargeted by hand or the URL silently 404s again with nothing reporting it.

Distinct from [[redirect-shadowed-by-alias]], which is about a redirect that
exists and cannot fire. This one is about a redirect that was never written.

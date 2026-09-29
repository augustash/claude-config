# `[neo:description]` resolves to the site slogan, so every page shares one description

**Symptom.** A Neo site's meta descriptions are wrong in one of two ways, and both look
identical from a browser because nobody reads a meta description while using a site:

- **Slogan set** → *every page on the site ships the same `<meta name="description">*. Site-wide
  duplicate content, on the one tag whose whole job is to differ per page.
- **Slogan empty** → *no page ships one at all.* An SEO audit reports "no meta description on
  any page" and it reads like a metatag misconfiguration.

**Cause.** `neo_metatag` ships `metatag.metatag_defaults.global` with
`description: '[neo:description]'`, and `neo_tokens_description()`
(`neo/neo.tokens.inc`) falls back to `system.site` slogan for everything except a
`taxonomy_term`, which uses its own description field. Nodes, products, views pages and
controllers all land on the fallback. The front page returns the slogan unconditionally,
before the alter hook even runs.

⚠ **The config is correct and the token is correct.** That is what makes it hard to see: the
tag is present in the defaults, the token is spelled right, and metatag simply omits a tag
whose value resolves to an empty string. There is nothing to find in the metatag UI.

⚠ **It propagates to three tags, and misses a fourth.** The same shipped config points
`twitter_cards_description` and `schema_article_description` at `[neo:description]` too — so an
empty slogan means an empty `twitter:description` and an `Article` graph with no `description`
in it. Meanwhile `og_description` **is not in Neo's defaults at all**, so a site can have a
populated meta description and still no Open Graph description. Check all four; fixing only
the one an audit named leaves the other three looking done.

## The whole Open Graph identity set is absent too, not just og_description

Neo's `metatag.metatag_defaults.global` ships `og_image*`, the `og_*` address tags and
`twitter_cards_*` — and **none of `og_title`, `og_type`, `og_site_name`, `og_url`,
`og_locale`**. So a Neo site serves a share card with an image and no title.

⚠ **Do NOT reason that a missing `og:title` falls back to `<title>`.** That is what the
fallback chain implies and it is not what LinkedIn does. On dmx-power.com (2026-09-25), with
`<title>DMX Power</title>` present and correct, LinkedIn's crawler walked the DOM and titled
the card **"Read the fault code"** — an `<h3>` from step 01 of an owner-steps list partway down
the homepage. The client screenshotted it from the post composer while drafting a launch post.

That is the real shape of the "random snippet" complaint, and it is worth holding onto because
the documented behaviour argues the other way: I had the diagnosis right, talked myself out of
it by reasoning from the spec, and only the client's screenshot settled it. **A crawler's
observed output beats its documented fallback.**

The fix is config, not code — add to `metatag.metatag_defaults.global`:

```
og_title: '[neo:title] | [site:name]'
og_site_name: '[site:name]'
og_type: website
og_locale: en_US
```

⚠ **Override `og_title` on the front-page default**, which already sets `title: '[site:name]'`.
The global pattern resolves there to `DMX Power | DMX Power`, because `neo_tokens_title()`
returns the site name unconditionally on the front page.

⚠ **`og_url` belongs in `hook_metatags_alter()`, copied from `canonical_url` — not given a
token.** Canonical is `[current-page:url]` globally, `[node:url]` on nodes and `[term:url]` on
terms, and any bundle may override it again; copying is what keeps the pair in step. A scraper
that sees the two disagree treats one page as two objects, so a shared link with `?fbclid=` or
`?utm_*` splits its engagement. Nothing about this is visible from a browser.

⚠ **Deploying the fix does not fix the preview.** LinkedIn caches per URL for ~7 days with no
purge button; re-scraping through **Post Inspector** (`linkedin.com/post-inspector/`) is the
only way, and it needs a login. Facebook is the same via Sharing Debugger's "Scrape Again". So
after any og change, force a re-scrape of every URL about to be posted **before** the client
posts, or they get the cached broken card on the one post that matters.

⚠ **On LinkedIn the card is title + domain only — no description renders.** So a home page's
`og:title` is the entire message there, and a bare site name reads as two words in a feed.

## Fixing it

Two seams, and which one is right depends on how many description sources the site has.

**One source → alter the token.** `hook_neo_token_description_alter(&$description, $params, $entity)`
is Neo's own extension point, invoked before the slogan fallback. Fill it and `description`,
`twitter_cards_description` and `schema_article_description` all resolve at once, because they
are the same token.

**More than one source → `hook_metatags_alter()`.** A catalog whose products derive their
description from their own token, and whose content pages take hand-written text, cannot route
both through `[neo:description]`. Alter the metatag array instead, then copy the resolved
value into the description-shaped tags:

```php
function MYMODULE_metatags_alter(array &$metatags, array &$context): void {
  $existing = trim((string) ($metatags['description'] ?? ''));
  // The unresolved token has to count as ABSENT — it is non-empty as a string
  // and resolves to nothing, so an emptiness test alone never fires.
  if ($existing === '' || $existing === '[neo:description]') {
    $metatags['description'] = /* … */;
  }
  foreach (['og_description', 'twitter_cards_description', 'schema_article_description'] as $tag) {
    $value = trim((string) ($metatags[$tag] ?? ''));
    if (!empty($metatags['description']) && ($value === '' || $value === '[neo:description]')) {
      $metatags[$tag] = $metatags['description'];
    }
  }
}
```

⚠ **`hook_metatags_alter()` runs BEFORE token replacement**, so every value it sees is the raw
token string. Testing for the literal `'[neo:description]'` is the check, not a hack around one.

⚠ **It fires for entity routes as well as route-only pages**, despite the api.php docblock
saying "pages that are not of content entities" — `metatag_get_tags_from_route()` merges the
entity's own tags first and then alters. One hook covers a node page and a views listing.

**Setting a slogan is not the fix.** It replaces "no description" with "the same description on
every page", which is worse: a unique-per-page tag carrying one site-wide string is a signal
that the pages are interchangeable.

Related: [[neo-skills-sync]], [[neo-color-scheme-token-resolution]].

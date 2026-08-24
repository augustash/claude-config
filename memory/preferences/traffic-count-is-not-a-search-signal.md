---
name: A legacy URL's pageviews say nothing about the words in it
description: high traffic on an old URL usually measures nav prominence, not demand for its phrasing — so it is not evidence for keeping a word in a new URL, label or heading
type: feedback
---

A legacy URL with heavy traffic is tempting evidence when naming its replacement:
*that page got 990 views, so the word in its path is the word people search.*
**It is not evidence of that, and the reasoning is worth catching before it
reaches a client document.**

A page linked from the old site's navigation accumulates views from people
already on the site. Whatever ranking it held came from its title and content,
not its slug. So the pageview count measures the page's *prominence*, and says
nothing about which phrasing drew anyone to it. One URL with no variants to
compare against is a single observation — there is no inference available from
it at all.

**Why:** on DMX Power this nearly put "locator" into the new URL, on the strength
of `/distributor-locator` being the old site's #4 URL. Checking how the term is
actually used showed the opposite — "locator" is the industry's word for the
*widget*, not a word customers type, and one source found was a glossary entry
defining it. Jargon needing a definition is not a search term.

**How to apply:** treat a traffic ranking as evidence about *demand for the
thing*, never about the words naming it. It justifies giving the page attention;
it does not justify a slug. The instrument for the wording question is query
data — Search Console impressions and clicks for the old domain — and when that
is not available, say so rather than substituting the number you do have.

Separately: slug keywords are a weak signal next to the title and heading, and
one page cannot rank well for three distinct intents. Where a client wants three
audiences named, the answer is usually three addressed pages, not three words in
one path.

Pairs with [[prove-code-is-dead]] — the same discipline of not letting an
available number stand in for the one that would actually settle the question.

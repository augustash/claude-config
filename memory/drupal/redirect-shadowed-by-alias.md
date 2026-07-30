---
name: A redirect never fires while its source path still has an alias
description: redirect module resolves the alias before looking a redirect up, so retiring a node needs the alias DELETED or the 301 sits in the table unreachable — and a custom access hook returning 403 hides it from redirect_404 too
type: reference
---

Retiring a node and pointing its old URL somewhere else takes **three** steps, not
two: unpublish, create the redirect, **and delete the path alias**. Skip the third
and the redirect is stored, correct, and permanently unreachable.

`RedirectRequestSubscriber::onKernelRequestCheckRedirect()` runs
`$this->pathProcessor->processInbound()` on the request path *before* looking the
redirect up:

```php
$path = $this->pathProcessor->processInbound($request->getPathInfo(), $request);
$path = trim($path, '/');
$redirect = $this->redirectRepository->findMatchingRedirect($path, ...);
```

So a live alias turns `news/201809/setup-my-thing` into `node/999160`, and the
lookup for `news/201809/setup-my-thing` misses. **The alias always wins.** One
path, one owner — after retirement that owner is the redirect, and the node keeps
`/node/N` for editors.

## Why it doesn't fall through to redirect_404

`redirect_404` catches 404s, so the natural assumption is that an unpublished node
404s and gets picked up there. It doesn't, if anything returns **403** first — and
a custom `hook_node_access` easily does. On md, `md_core_node_access()` treats an
unpublished composed page as internal:

```
CacheableAccessDeniedHttpException: Internal composed pages require the
"view internal pages" permission.
```

403, not 404, so `redirect_404` never sees it either. Anonymous gets an access
denied on a page that is supposed to be redirecting.

## Diagnosing

The stored row looks perfect, which is the whole trap — don't verify from the
`redirect` table. Verify from **outside, anonymously, without following the
redirect**, and assert the status code:

```
curl -sI https://site.ddev.site/old/path        # want 301 + Location
```

`403` = something is claiming the path ahead of the redirect (alias, or an access
hook). `200` = the alias is still resolving and the node still renders. Either way
the redirect is not in play. A logged-in check hides the 403 case entirely.

Fragments survive fine — `internal:/support#guides` arrives as
`Location: /support#guides`, so an in-page anchor is a legitimate redirect target.

## Retiring in bulk

Capture each alias **before** deleting it — after deletion
`lookupBySystemPath()` returns NULL, so a verify pass written to re-look-it-up
silently checks nothing and reports all-clear. Collect the paths in the same loop
that deletes them. Reference implementation: md's
`scripts/retire-howto-articles.php`.

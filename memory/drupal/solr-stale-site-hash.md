---
name: A Solr core keeps documents under an old site hash
description: A Search API view returns far more results than the site has content, while search-api:status says 100% indexed and clear + reindex change nothing.
type: reference
---

A listing returns roughly double what exists — 1119 results against 512 nodes — and every
check says the index is healthy. `search-api:status` reports 100%, `search-api:clear` reports
success, a full reindex finishes cleanly, and the count does not move.

The core is holding documents written under a **previous site hash**. Each document carries
`index_id` and `hash`; a site rebuild, a database clone between environments, or a re-created
environment gives the site a new hash, and everything indexed under the old one is stranded.

**Why the normal workflow can't reach it:**

- **`search-api:clear` deletes hash-scoped** — it removes `index_id:<index> AND hash:<current>`.
  Old-hash documents don't match, so it reports success having missed them entirely.
- **The search query does not filter on hash** — so those same documents come straight back in
  results. Deletion is scoped, retrieval isn't, and the gap is where they live.

The tracker is a database table listing what Drupal *thinks* it put in the index. It has no
idea what else is in there, so "100% indexed" is true and useless.

## Diagnose

Compare the index's own query count against the content count — not the tracker:

```php
$i = \Drupal::entityTypeManager()->getStorage('search_api_index')->load('careers');
$q = $i->query(); $q->range(0, 0);
print $q->execute()->getResultCount();   // vs the node count
```

Then facet the raw core by `hash` to see the split:

```php
$b = $i->getServerInstance()->getBackend();
$c = $b->getSolrConnector();
$e = $b->getCollectionEndpoint($i);
$s = $c->getSelectQuery(); $s->setQuery('*:*'); $s->setRows(0);
$s->getFacetSet()->createFacetField('h')->setField('hash')->setMinCount(1);
foreach ($c->execute($s, $e)->getFacetSet()->getFacet('h') as $hash => $n) {
  print "$hash -> $n\n";
}
```

More than one hash is the answer. `Utility::getSiteHash()` gives the current one; everything
else is dead. Dumping a stray document also dates it — a 2022 `timestamp` against a site
rebuilt since makes the story obvious.

## Fix

Delete by query on the stale hash, which is the only operation that reaches them:

```php
$u = $c->getUpdateQuery();
$u->addDeleteQuery('hash:4qx74p');
$u->addCommit();
$c->update($u, $e);
```

This clears every index on that hash at once, so a polluted site search gets fixed in the same
pass. Nothing real is lost — anything current re-indexes.

## Check every environment separately

The hashes are per-environment and accumulate independently. On wps 2026-09-08: dev carried
1120 stale documents under `4qx74p`, test carried 1127 under `1gff0e`, and **live was clean**.
Don't infer one environment's state from another, in either direction — a broken dev proves
nothing about live, and a clean live proves nothing about the environment a client is
reviewing.

Pairs with [[search-api-solr-convention]] for the standard index/server naming.

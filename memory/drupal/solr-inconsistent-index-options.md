---
name: solr-inconsistent-index-options
description: Solr rejects every document with "cannot change field … to inconsistent index options", and clear + reindex keeps failing identically.
metadata:
  type: reference
---

Every write fails with a 400 like:

```
cannot change field "tm_X3b_en_rendered_item" from index options=DOCS_AND_FREQS_AND_POSITIONS
to inconsistent index options=DOCS_AND_FREQS_AND_POSITIONS_AND_OFFSETS
```

The schema on the core now wants a field indexed one way (here: with offsets) and Lucene
already holds that field indexed the old way. Lucene will not mix the two for one field name,
so nothing new gets in. The site keeps serving whatever was indexed before. That makes it
silent: `search-api:status` sits well short of 100% (wps live, 2026-10-29: Global 42%,
Careers 0%) and nothing else looks broken. Content saves log the error, but the log may be too
short to show how long it has been failing.

**Why clear + reindex doesn't fix it.** Lucene keeps each field's index options in two places
that a delete doesn't touch:

- **Segments.** A delete only marks documents deleted. Their segments, and the field info they
  carry, stay until merged away.
- **The open IndexWriter.** It keeps a global field-number map in memory for its lifetime, and
  rebuilds it from the segments on open.

So with 0 documents in the core, the reindex still fails identically.

## Fix, in this order (wps live, 2026-10-29)

1. `drush search-api-pantheon:postSchema`: put the current schema on the core. It reloads
   the core too, but the old segments are still there, so the old options survive.
2. `drush search-api:clear <index>` for each index on the core.
3. Optimize, which merges away the now-all-deleted segments:
   ```php
   $i = \Drupal::entityTypeManager()->getStorage('search_api_index')->load('global');
   $b = $i->getServerInstance()->getBackend();
   $c = $b->getSolrConnector(); $e = $b->getCollectionEndpoint($i);
   $u = $c->getUpdateQuery(); $u->addOptimize(TRUE, TRUE, 1); $c->update($u, $e);
   ```
4. `drush search-api-pantheon:reloadSchema`: reopen the writer on an empty index. **This is
   the step that's easy to skip.** After 1–3 alone, the reindex still failed on every item.
5. `drush search-api:index`.

All indexes on that core are empty between steps 2 and 5. A full reindex of ~2,100 items took
a few minutes. If it still fails after step 4, Pantheon support can reset the core.

`clear` only deletes the current site hash. Facet the core on `hash` first, as in
[[solr-stale-site-hash]], so stale-hash documents don't survive step 2 and keep the old
options alive.

Pairs with [[search-api-solr-convention]].

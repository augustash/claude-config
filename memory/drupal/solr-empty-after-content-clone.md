---
name: A cloned environment reports 100% indexed and returns nothing
description: After env:clone-content on Pantheon, search returns zero results while search-api:status says 100%. The tracker rode up in the database; the Solr documents did not.
type: reference
---

# A cloned environment reports 100% indexed and returns nothing

Clone content to another environment — `terminus env:clone-content <site>.<src> <target>`,
or any database copy between environments — and the target's search comes back **empty**:

```
$ terminus drush <site>.<env> -- search-api:status
  global   Global   100%   70   70          ← says everything is indexed

$ curl -s "https://<env>-<site>.pantheonsite.io/<search endpoint>?q=<known term>"
[]                                           ← returns nothing
```

Every page renders, content is plainly there, and the index reports complete. Only the search
is dead, so it reads as a broken view or a bad query rather than an empty core.

## Why it lies

**`search-api:status` reads the TRACKER, which lives in the database.** Cloning the database
copies the source environment's tracker rows, which say every item is indexed — a true
statement about the environment they were written on. The Solr documents live in the target's
own core and were not part of the clone, so the core is empty and the bookkeeping that would
tell you sits in the copy you just overwrote.

Each environment has its own core by design. `search_api.server.*` is usually in
`config_ignore` for exactly that reason — the connection details are environment-specific —
so `cim` will not repoint or repopulate anything either.

## Fix

Reset the tracker so it stops claiming the work is done, then index:

```
terminus drush <site>.<env> -- search-api:reset-tracker global
terminus drush <site>.<env> -- search-api:index global
```

Re-run `search-api:index` until it reports *"The index Global is up to date"* — it works in
batches (50 items by default) and one invocation may not finish the set.

**Verify with a real query, not with `search-api:status`.** The status command will report
100% both before and after, so it cannot tell you whether the fix worked. Hit an endpoint that
actually queries Solr and confirm it returns rows.

## Where it bites

Every hop of a launch: `dev → test → live` needs this on **each** target, and it is silent on
each one. The page a stakeholder happens to open looks perfect.

⚠ Not the same failure as [[solr-stale-site-hash]], and they resolve oppositely:

| | this memory | solr-stale-site-hash |
|---|---|---|
| Symptom | **zero** results | **too many** results |
| `search-api:status` | 100% | 100% |
| Reindex | **fixes it** | changes nothing |
| Cause | target core never populated | core holds documents under an old site hash |

If a reindex does not fix an empty index, or the count is too high rather than zero, stop and
read that one instead.

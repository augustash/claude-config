# An exposed taxonomy filter reads as a list that repeats

A views exposed taxonomy dropdown that looks alphabetical but starts over
partway down — A→T, then A→W again — is not duplicated data. Views builds the
options from the term tree, which sorts by **weight, then name**. A vocabulary
where some terms carry a legacy manual ordering (weights 1..n from someone
dragging the overview page once, years ago) and the rest sit at weight 0 renders
as two alphabetical runs, one per weight band. Checking for duplicate term names
comes back clean and looks like a dead end.

**Don't fix it by zeroing the weights.** Term weight is content, not config, so
that's a data step on every environment, and one drag on the vocabulary overview
page brings it back. Sort the `#options` in `hook_form_alter()` instead — one
deployable fix that holds everywhere. Keep `All` pinned first, and prefer
`strcasecmp` over `strnatcasecmp`: natural compare collapses whitespace, so it
files `Landscape Architecture` before `Land Surveying`.

## The exposed input is not in #default_value yet

When altering a views exposed form, `$form[$identifier]['#default_value']` is
still the widget default (`'All'`) — Views applies the exposed input after the
alter. The active choice is on the view:

```php
$view = $form_state->get('view');
$active = $view ? $view->getExposedInput() : [];
```

This matters the moment you *remove* options: an active filter whose last node
just went away has to stay in the list, or the select silently falls back to
`All` while the results shown are still filtered.

## Options that can only return "no results"

The same filter offers every term in the vocabulary whether or not any content
references it. Pruning is an aggregate query per field, cached and tagged so it
re-derives on the next node save:

```php
$result = \Drupal::entityTypeManager()->getStorage('node')->getAggregateQuery()
  ->accessCheck(FALSE)
  ->condition('type', $bundle)
  ->condition('status', 1)
  ->groupBy($field . '.target_id')
  ->execute();
$tids = array_column($result, $field . '_target_id');
```

Tag both the cache item and `$form['#cache']['tags']` with
`node_list:<bundle>`; core invalidates that on every save of that bundle, so the
dropdown gains and loses options on its own with no cron or manual clear. Verify
in both directions — attach a term to a node and confirm the option appears
without a `cr`, then revert and confirm it goes.

One caveat where the view is Search API backed and the index isn't
`index_directly`: the option list comes from the database and the results come
from the index, so a brand-new posting can put its term in the dropdown a cron
run before the job is searchable. Deriving the list from the index instead trades
that for a worse failure — every option vanishing during a reindex — so the
database is the right source.

Worked through on wps (`wps_careers_search.module`), where a Paylocity feed
auto-creates the vocabulary and nobody has hand-ordered it since 2024.

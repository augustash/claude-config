---
name: charts-data-chart-moved
description: charts 5.2.4 moved data-chart into content['chart'], so preprocess overrides of chart colours or types silently stop applying
metadata:
  type: reference
---

# charts 5.2.4 moved `data-chart`, and preprocess overrides go quiet

`template_preprocess_charts_chart` used to leave the encoded definition at
`$variables['content']['#attributes']['data-chart']`. In charts 5.2.4 (seen bumping from
5.2.2) `content` is a figure wrapper and the attributes sit on `content['chart']`. A custom
`hook_preprocess_charts_chart()` that decodes, edits and re-encodes the old key now reads
NULL. Charts render with library defaults, and each chart logs "Undefined array key
#attributes" and "foreach() argument must be of type array" warnings. No error appears on the page.

**Don't just repoint at the new key.** Use charts' API instead:
`hook_chart_definition_alter(array &$definition, array $element, $chart_id)` gets the same
array before it is JSON-encoded, so it doesn't depend on the template's layout at all.
`$element['#chart_type']` and any custom `#` keys you set are available. mace commit `067dd0dd5`
is the worked example (gauge colour pattern, area types).

```bash
grep -rn "preprocess_charts_chart" web/modules/custom web/themes/custom
```

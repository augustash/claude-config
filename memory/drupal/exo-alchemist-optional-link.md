---
name: exo_alchemist optional link field
description: Making an exo_alchemist 'link' field truly optional — required:FALSE alone does nothing
type: project
---

In an exo_alchemist component YAML, setting `required: FALSE` on a `link` field has no effect — that's already the default (`ExoComponentDefinitionField.php` `'required' => FALSE`). To actually let editors leave a link blank without it being re-populated from defaults:

```yaml
link:
  type: 'link'
  label: 'Link'
  cleanup: FALSE
  title_type: 'optional'
  default:
    uri: 'internal:/'
    title: 'Find Out More'
```

- `cleanup: FALSE` — `ExoComponentFieldFieldableBase::populateValues()` (~line 92) returns the editor's actual value instead of reapplying YAML defaults to non-empty items. Without it, a cleared link snaps back to the default.
- `title_type: 'optional'` — sets the link field's title storage to `DRUPAL_OPTIONAL` (Link.php `getStorageConfig()`); default is `DRUPAL_REQUIRED`, which blocks saving with empty title.

Twig also needs `{% if feature.link.url %}` (not `{% if feature.link %}`) — the link value object is always truthy, so the bare check renders an empty `<a>` when the URI is cleared.

**Why:** discovered while making `features_icon` link optional on the sisal project — `required: FALSE` was a no-op, the working pattern was `cleanup: FALSE` (matching `banner_slider.yml`) plus `title_type: 'optional'`.

**How to apply:** when an editor asks to make any link field in an exo_alchemist component optional, jump to this combo instead of fiddling with `required`. Always check the twig's truthiness check on the same pass.

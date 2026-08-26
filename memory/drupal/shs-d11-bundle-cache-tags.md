---
name: shs 2.0.6 calls a D11-only cache-tag method and empties every widget on D10
description: shs 2.0.6's ShsTermCacheDependency::getCacheTags() calls EntityTypeInterface::getBundleListCacheTags(), added in core 11.x only, while the module still declares ^10.5. On Drupal 10 every /shs-term-data/* request 500s, so every Simple Hierarchical Select renders empty selects with the stored value gone from view. Data is untouched. Carries the method_exists() patch.
type: reference
---

# shs 2.0.6 calls a D11-only cache-tag method and empties every widget on D10

**Symptom.** Every Simple Hierarchical Select widget on the site renders its selects with no
options — including the level that should show the *stored* value. Reads as data loss or a
broken field, but the rows in `taxonomy_term_field_data` and the reference field are fine. It
hits **every** field using the widget at once, across bundles and entity types, because they
all go through one endpoint.

**Cause.** shs **2.0.6** ([#3613025](https://www.drupal.org/project/shs/issues/3613025)) added
vocabulary-specific list cache tags:

```php
// src/Cache/ShsTermCacheDependency.php::getCacheTags()
$entity_type->getBundleListCacheTags($this->bundle)
```

`EntityTypeInterface::getBundleListCacheTags()` was added to core **11.x only**
([#3501508](https://www.drupal.org/project/drupal/issues/3501508)), but `shs.info.yml` still
declares `^10.5 || ^11.1`. So on any Drupal 10 site the module installs cleanly, the form
renders, and then every AJAX call fatals:

```
Call to undefined method Drupal\Core\Entity\ContentEntityType::getBundleListCacheTags()
```

**The failure is invisible from the form.** shs builds its selects entirely from
`/shs-term-data/{identifier}/{bundle}/{parent}`, so a 500 there just yields empty selects with
no PHP error on the page. Don't debug the widget — `curl` the endpoint:

```
curl -sk -w "\nHTTP %{http_code}\n" \
  "https://<site>/shs-term-data/<entity_type>:<bundle>:<field_name>/<vocabulary>/0"
```

It's `_permission: 'access content'`, so an anonymous curl reaches it. `0` is the root level;
pass a tid to test the child level. A healthy response is a JSON array of
`{tid,name,description__value,langcode,hasChildren}`.

**Fix.** Guard the call — keeps the tighter invalidation on D11, falls back to the generic
`taxonomy_term_list` tag on D10:

```php
// getBundleListCacheTags() is Drupal 11 only (core #3501508), but this module
// still supports ^10.5.
if ($this->bundle !== NULL && method_exists($entity_type, 'getBundleListCacheTags')) {
```

**Still unfixed as of 2.0.7** (checked 2026-08-26: `ShsTermCacheDependency::getCacheTags()`
calls `getBundleListCacheTags()` unguarded). Keep the patch; re-check on the next release.

Local patch, pending an upstream release — `patches/shs-bundle-list-cache-tags-d10.patch`
(first written on the msp project). Contrib is gitignored on Pantheon-style projects, so this
has to ride as a `cweagans/composer-patches` entry, not an edit to the installed copy; see
[[patches]]. Pinning back to 2.0.5 also works but drops the other 2.0.6 fixes (truncated
values, duplicate values, multilingual term names, PHP 8.5 deprecations).

Same shape as [[exo-d11-image-formatters]] — a contrib module adopting a new-core API without
tightening its own `core_version_requirement`. When a contrib bump breaks a site on the older
core branch, check the diff for core methods that don't exist locally before assuming config
or data drift:

```
grep -rn "getBundleListCacheTags" web/core/lib/
```

An empty result on a method the module calls unconditionally *is* the answer.

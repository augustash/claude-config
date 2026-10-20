---
name: exo-link-menu-d11-menu-settings
description: On D11.1+ exo_link_menu silently removes the "Menu settings" section from every node form; it guards a call to a menu_ui procedural hook that core moved into MenuUiHooks. Local patch pattern and how it was caught.
metadata:
  type: reference
---

# exo_link_menu drops node-form menu settings on D11.1+

`exo_link_menu` takes over core's node-form menu UI so it can add an icon picker.
It does this in two steps:

- `hook_module_implements_alter()` unsets `menu_ui` from `form_node_form_alter`.
- Its own alter then calls `menu_ui_form_node_form_alter()`, wrapped in
  `if (function_exists(...))`.

D11.1+ converted that hook to `\Drupal\menu_ui\Hook\MenuUiHooks::formNodeFormAlter()`
with **no procedural function left**. The guard is false, so eXo adds nothing.
Core's own alter was already removed. **Every node form loses its menu settings,
with no error, no log entry, and the form still returns 200.** Editors simply
can't place pages in menus any more.

**Status:** still broken on `jacerider/exo` 2.0.30 (`fed87dd`,
2026-10-08); checked 2026-10-19, the `function_exists()` guard is unchanged. Carried as a local patch on aailoft,
`patches/exo-link-menu-d11-menu-ui-hooks.patch`. The fix belongs upstream on
`develop` ([[module-fixes-on-develop]]). Delete this memory once a release carries it.

## The fix

```php
if (class_exists(MenuUiHooks::class)) {
  \Drupal::service(MenuUiHooks::class)->formNodeFormAlter($form, $form_state);
}
elseif (function_exists('menu_ui_form_node_form_alter')) {
  menu_ui_form_node_form_alter($form, $form_state, $form_id);
}
```

The submit-handler swap needs the same care. Core's handler is now the string
`MenuUiHooks::class . ':formNodeFormSubmit'`, not `'menu_ui_form_node_form_submit'`,
so eXo's `array_search` for the old name also silently misses. Match both.
`menu_ui_get_menu_link_defaults()` still exists (deprecated) in 11.4.

## How it was caught

Not by status codes. A regression crawl flagged node add/edit forms as ~110 KB
smaller than D10, the same amount on every node form. That points to one missing
shared element, not a missing field. Diffing the `name=` attributes against the
same form on a still-D10 environment showed only `menu` missing. The bulk was the
menu-parent `<select>`.

Verify by building the form as uid 1 (`isset($form['menu'])`), then submitting it
with `menu[enabled]` and checking a `menu_link_content` row appears.

Any other module that calls a core `*_form_*_alter()` behind `function_exists()`
has the same failure mode. See the grep in the drupal-11-upgrade skill.

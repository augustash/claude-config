---
name: exo_icon breaks kernel tests; decouple it from testable logic
description: exo_icon's hook_entity_type_alter assumes node_type exists, so enabling it in a KernelTestBase (directly or transitively) blows up the entity-type rebuild — keep it out of kernel test module lists, and stand in for any field type it gates.
type: feedback
---

# exo_icon breaks kernel tests; decouple it from testable logic

`exo_icon` (the eXo icon module) is **not kernel-test friendly**. Enabling it in a `KernelTestBase` (directly in `$modules`, or transitively via a module that depends on `exo:exo_icon`) blows up during the entity-type rebuild:

```
Undefined array key "node_type"
.../exo/exo_icon/exo_icon.module:249   (its hook_entity_type_alter assumes node_type exists)
```

Its `hook_entity_type_alter` assumes a full site (a `node_type` entity), so a minimal kernel bootstrap fatals before any test runs. Pulling in `node` + the rest to satisfy it bloats the test to bootstrap exo's whole world just to render an icon glyph — which is testing exo's job, not ours (violates [[trust-contrib-tests]]).

**The fix is a design one, not a test hack:** keep `exo_icon()` calls out of the logic you want to test. Have the service/builder return structured data (`['icon' => 'sisal-bag', 'text' => ...]`) and render the icon in the **template preprocess** (`template_preprocess_*` calling `exo_icon($text)->setIcon($name)`). Then:

- the logic (gating, formatting, resolution) is kernel/unit-testable with zero exo bootstrap — assert on the structured output, not rendered HTML;
- the icon still renders via exo at display time in the real site, where exo_icon is always enabled.

This is better separation regardless of testing (data vs. presentation), so the test pressure surfaces the right architecture rather than forcing a workaround.

**Aside — declare the dependency.** A module that calls `exo_icon()` at runtime genuinely depends on it; add `exo:exo_icon` to its `.info.yml` even though you've decoupled it from the test path. Missing that is a real bug (undefined function on a fresh enable), independent of tests. `exo_icon` is provided by the `exo` package (`web/modules/contrib/exo/exo_icon`), deps `exo_config_file` + `exo_modal`.


## When the module you need drags it in

The advice above assumes you own the code calling `exo_icon()`. When the module you must
enable is one you can't redesign — `commerce_rug`, for one — there is no decoupling to do.
It cannot boot in a kernel test at all, and the reason is worth knowing before you start:
its `RugBorder` entity declares an `icon` base field, and that field type is exo_icon's
`IconItem`.

**The symptom never names exo_icon.** It arrives as a cascade of unrelated missing plugins,
each one looking like the last module you need:

```
non-existent service "photoswipe.assets_manager"
  → "color_field_type" plugin does not exist
  → "image" plugin does not exist            (via RugColorViewsData building views data)
  → 'category' references target entity type 'taxonomy_term' which does not exist
  → "icon" plugin does not exist             ← dead end
```

Five rounds of "add the missing module" that read like progress, ending somewhere no module
list reaches — `node` would satisfy exo_icon's `node_type` lookup, but by then the test
bootstraps most of a site to assert one thing.

**Stand in for the field instead of chasing the chain.** The code under test almost never
touches exo's field *type* — it reads a value. Declare the field yourself with a core type
of the same shape and skip the module: `commerce_rug`'s `rug_data` is a serialized array in
a single `value` column, so a plain `string_long` holding `serialize([...])` exercises the
same reads. Check the real column shape in the live DB first — production storage is the
spec, and it can differ per row (rug_data comes back a string for rugs and pads, an array
for some samples).

Cheap to sanity-check before committing to it: enable the module in a throwaway test and
read the error. If the chain ends at `icon`, stop and substitute.

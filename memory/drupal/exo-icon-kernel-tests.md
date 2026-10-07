---
name: exo_icon breaks kernel tests; decouple it from testable logic
description: exo_icon's hook_entity_type_alter assumes node_type exists, so enabling it in a KernelTestBase fatals the entity-type rebuild — decouple your own logic from it; when a module needs it (commerce_rug), add node, breakpoint and views and it boots.
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
enable is one you can't redesign — `commerce_rug`, for one — there is no decoupling to do,
and its `RugBorder` entity declares an `icon` base field whose type is exo_icon's `IconItem`.

**The symptom never names exo_icon.** It arrives as a cascade of unrelated missing plugins,
each one looking like the last module you need:

```
non-existent service "photoswipe.assets_manager"
  → "color_field_type" plugin does not exist
  → "image" plugin does not exist            (via RugColorViewsData building views data)
  → 'category' references target entity type 'taxonomy_term' which does not exist
  → "icon" plugin does not exist
```

**It does boot — enable exo_icon and what it assumes.** This was once written up here as a
dead end; on sisal (2026-10-07) the full stack installed once three modules beyond the
declared dependencies were named: `node` (exo_icon's `node_type` lookup), `breakpoint`
(`exo_imagine.manager` needs `breakpoint.manager`) and `views`. Plus `commerce_number_pattern`
if `commerce_order` config is installed. Working list, on `CommerceKernelTestBase`:

```
node, breakpoint, views, taxonomy, image, file, text, options, path, path_alias,
entity_reference_revisions, profile, state_machine, commerce_product,
commerce_number_pattern, commerce_order, color_field, exo, exo_icon, exo_imagine,
photoswipe, google_tag, commerce_rug
```

Reference: `web/modules/custom/commerce_rug/tests/src/Kernel/RugRateCardTest.php` on sisal,
which also shows the fixture traps (`RugColor::preCreate()` appends the default size to any
sizes you pass; borders and colors need an explicit `weight`; the module's install config
ships no pads).

**When the test only reads a value, stand in instead.** If the code under test touches no
rug entity — it just reads `rug_data` off a product — declaring the field yourself with a core
type of the same shape is lighter than booting the stack: `rug_data` is a serialized array in
a single `value` column, so a plain `string_long` holding `serialize([...])` exercises the same
reads. Check the real column shape in the live DB first — production storage is the spec, and
it can differ per row (rug_data comes back a string for rugs and pads, an array for some
samples). Boot the real stack when the logic reads the entities themselves.

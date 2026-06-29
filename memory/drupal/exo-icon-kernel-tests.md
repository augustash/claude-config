---
name: exo_icon breaks kernel tests; decouple it from testable logic
description: exo_icon's hook_entity_type_alter assumes node_type exists, so enabling it in a KernelTestBase (directly or transitively) blows up the entity-type rebuild — keep it out of kernel test module lists.
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

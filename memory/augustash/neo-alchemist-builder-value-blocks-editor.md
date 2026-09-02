---
name: A builder-written prop value the editor rejects makes the component unsaveable
description: "Builders write straight to storage and never validate; the editor does. A value the schema disallows renders perfectly and then blocks the component save, naming no field — the component modal simply never returns to layout level. `type: string` capped at 255 is the common case; `format: textarea` is the fix."
type: reference
---

# A builder-written prop value the editor rejects makes the component unsaveable

Affects any Neo component whose props are written by a build script rather than
typed into the editor — i.e. every page we compose programmatically.

**The two write paths do not agree.** A builder assembles props and saves the
entity, which never runs the component form's validation. The editor builds a
real form from the same schema and *does* validate. So a value the schema
disallows is written happily, renders perfectly, and lies dormant until the first
person opens that component — at which point it can never be saved again.

## The tell

A component that is visibly fine on the page cannot be saved in the editor. The
component-level save appears to do something and then **never returns you to
layout level**, so the entity-level save is never reachable. No field is
identified and usually no error text appears at all.

⚠ **The entity does not move.** Alchemist parks component edits in
`tempstore.private.neo_alchemist` and only the layout save writes the node — so
the node sits on its old revision through every attempt while the editor shows
the value updating. That reads as "nothing saves", which sends you hunting a
persistence bug instead of a validation one. (Distinct from
[[neo-alchemist-layout-save-confirm]], where the two-step save is working
normally and just needs its second click.)

## Why the error is invisible

`FormErrorHandler::setElementErrorsFromFormState()` walks the element tree to
attach messages and calls `FormState::getError()` on each child. Several
Alchemist elements are raw render arrays with no `#parents`, so the walk emits a
wall of

```
Warning: Undefined array key "#parents" in Drupal\Core\Form\FormState->getError()
```

instead of the message. Those warnings **prove errors exist** — `getError()` only
reads `#parents` inside `if ($errors = $this->getErrors())` — but they name
nothing.

**To see the actual errors**, append a `#validate` handler and log
`$form_state->getErrors()`, which is keyed by element path:

```php
function mymodule_form_alter(array &$form, FormStateInterface $form_state, string $form_id): void {
  if (str_contains($form_id, 'component') || str_contains($form_id, 'alchemist')) {
    $form['#validate'][] = 'mymodule_debug_validate';   // named, NEVER a closure
  }
}
```

⚠ **`#after_build` is the wrong hook** — it runs *before* validation, so it always
reports an empty error list. ⚠ **A closure is not usable in either hook**: the
form array is serialized into the form cache, so `Serialization of 'Closure' is
not allowed` breaks the very save being diagnosed.

## The common cause: `type: string` is capped at 255

`StringShape` declares `default_field_type: 'string'` — a Drupal `string` field,
maximum 255 characters. Any prop holding a sentence or a paragraph will exceed it
eventually.

```
Super copy cannot be longer than 255 characters but is currently 432 characters long.
```

**Fix — `format: textarea`**, which `StringShape` declares as a format whose
`default_field_type` is `string_long`. Same string value, no cap, and a textarea
is the right control for prose anyway:

```yaml
super_copy:
  type: string
  format: textarea    # string_long — uncapped
  title: 'Super copy'
```

`ComponentShapePluginBase::getFormat()` reads it straight off the schema, so no
other wiring is needed.

## The same trap with `enum`

An `enum` makes the prop a select and validates against its allowed values. If a
builder writes an **empty string** for the items that have no value — and it must
write the key, or Alchemist's example seed stands instead
([[neo-alchemist-example-seeding]]) — then `''` has to be *in* the enum, or every
such item fails validation the moment the component is opened:

```yaml
enum: ['', red, yellow, green]
```

## Find them all before they bite

[templates/audit-string-prop-overflow.php](../../templates/audit-string-prop-overflow.php)
walks every stored component tree and reports string props holding over 255
characters, per component and entity. Two things it does that a naive version
gets wrong, both of which produced a confident, wrong "nothing found":

- **Audits stored VALUES, not schemas.** A `type: string` prop is only a problem
  once something actually wrote past the cap.
- **Reads the LIVE SDC definition** (`plugin.manager.sdc`), never the
  `neo_component` entity's stored `schema`/`expression`. That snapshot re-syncs on
  its own triggers — *not* on `drush cr` — so a prop just fixed still looks broken
  there.

⚠ Its field type is `neo_component_tree`, not `neo_component`, and the tree must
be walked **recursively** — components dropped into a `region` prop nest a level
down and a flat loop skips them silently. Both mistakes yield a clean bill of
health that looks identical to a real one, so **self-test any change to it against
a known offender** before believing a pass.

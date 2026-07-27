# Alchemist layout Save needs a second click, and nothing persists without it

Component edits in neo_alchemist land in a **draft**, not on the entity. The
component form's own Save ("Updated component X successfully") writes the draft;
the entity is only written by the layout toolbar's **Save**, and that opens a
confirmation modal — *"Save the components on <label>?"* — whose own Save button
is the click that actually persists. Clicking the toolbar button and walking
away publishes nothing.

## Why this is worth knowing

The failure mode is indistinguishable from a persistence bug. Everything that
reads the draft looks correct — the editor form reloads with the new values on a
fresh page load, the live preview re-renders, the success message appears — while
the entity's stored props keep the old data. Debugging from the stored side
(`node__field_*.props`) shows changes "not saving" and sends you hunting through
`massageFormValues()`, `saveComponents()`, and the field item for a strip that
does not exist.

Tell them apart before investigating:

- Toolbar **Save / Revert / Reset** enabled = there are unpublished draft
  changes. That alone says the draft holds something the entity does not.
- **Revert** (also confirm-gated) discards the draft and restores the entity's
  values — the clean way out of a draft you no longer want.

Drafts live in the `neo_alchemist` PrivateTempStore, keyed per field item; see
`ComponentTreeItem::getDraftKey()` / `saveComponents()`.

## Driving it from browser automation

The modal is a Drupal dialog: the visible control is the **button pane** proxy,
not the form's own submit, and both match a search for "Save". Click the button
pane one. A click that misses leaves the dialog open and the page unchanged,
which reads exactly like a save that silently failed — always confirm against
stored data rather than the editor UI.

Related: [[neo-alchemist-nested-markup]]

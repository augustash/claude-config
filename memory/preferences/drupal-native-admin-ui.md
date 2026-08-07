---
name: drupal-native-admin-ui
description: Building rich admin UIs on Drupal projects — reach for core AJAX/dialog/tabledrag and Drupal.behaviors, not React
metadata:
  type: feedback
---

**On Drupal projects, build rich admin UIs with Drupal-native tech, not React** (or any
framework needing a JS build pipeline): core dialog API for modals (`data-dialog-type`,
`OpenModalDialogCommand` — existing entity forms open in modals for free), core tabledrag /
`DraggableListBuilder` for drag-and-drop weight reordering, the AJAX framework (`use-ajax`,
AJAX commands) for inline actions, `Drupal.behaviors` for custom JS.

**Why:** Dane (kow, 2026-08-06), when a promotions-admin overhaul was scoped with React:
"its drupal you don't need react sorry use ajax or javascript." Native gets the react-like
feel (modals, drag-drop, live updates) with no build step, no vendored bundles, admin-theme
styling for free, and code any Drupal dev on the team can maintain.

**How to apply:** when an admin UI overhaul is requested, propose the Drupal-native stack
first and mention that existing edit forms can be reused inside modals — that reuse is
usually the decisive simplification. A JS framework needs an explicit justification (e.g. a
genuinely stateful canvas-style editor) and the developer's sign-off.
